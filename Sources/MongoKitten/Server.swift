//
//  NewDatabase.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 24/01/16.
//  Copyright © 2016 OpenKitten. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import Socks

@_exported import BSON

import Foundation
import MongoMD5

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// This file contains the low level code. This code is synchronous and is used by the async client API. //
//////////////////////////////////////////////////////////////////////////////////////////////////////////


/// A ResponseHandler is a closure that receives a MongoReply to process it
/// It's internal because ReplyMessages are an internal struct that is used for direct communication with MongoDB only
internal typealias ResponseHandler = ((Message) -> Void)

/// A server object is the core of MongoKitten as it's used to communicate to the server.
/// You can select a `Database` by subscripting an instance of this Server with a `String`.
public final class Server {
    /// The authentication details that are used to connect with the MongoDB server
    private let authDetails: (username: String, password: String, against: String)?
    
    /// The last Request we sent.. -1 if no request was sent
    internal var lastRequestID: Int32 = -1
    
    /// The full buffer of received bytes from MongoDB
    internal var fullBuffer = [Byte]()
    
    /// A cache for incoming responses
    #if os(Linux)
    private var incomingMutateLock = Lock()
    #else
    private var incomingMutateLock = NSLock()
    #endif
    
    private var incomingResponses = [(id: Int32, message: Message, date: Date)]()
    
    /// Contains a map from an ID to a handler. The handlers handle the `incomingResponses`
    private var responseHandlers = [Int32:ResponseHandler]()
    
    #if os(Linux)
    private var waitingForResponses = [Int32:Condition]()
    #else
    private var waitingForResponses = [Int32:NSCondition]()
    #endif
    
    /// `MongoTCP` Socket bound to the MongoDB Server
    private var client: MongoTCP?
    public let tcpType: MongoTCP.Type
    
    /// Did we initialize?
    private var isInitialized = false
    
    /// The server's hostname/IP and port to connect to
    public let server: (host: String, port: UInt16)
    
    internal private(set) var serverData: (maxWriteBatchSize: Int32, maxWireVersion: Int32, minWireVersion: Int32, maxMessageSizeBytes: Int32)?
    
    /// Sets up the `Server` to connect to the specified URL.
    /// The `mongodb://` scheme is required as well as the host. Optionally youc an provide ausername + password. And if no port is specified `27017` is used.
    /// You can provide an alternative TCP Driver that complies to `MongoTCP`.
    /// This Server doesn't connect automatically. You need to either use the `connect` function yourself or specify the `automatically` parameter to be true.
    ///
    /// - parameter url: The MongoDB connection String.
    /// - parameter tcpDriver: The TCP Driver to be used to connect to the server. Recommended to change to an SSL supporting socket when connnecting over the public internet.
    ///
    /// - throws: When we can't connect automatically, when the scheme/host is invalid and when we can't connect automatically
    ///
    /// - parameter automatically: Whether to connect automatically
    public convenience init(_ url: NSURL, using tcpDriver: MongoTCP.Type = Socks.TCPClient.self, automatically connecting: Bool = true) throws {
        guard let scheme = url.scheme, let host = url.host , scheme.lowercased() == "mongodb" else {
            throw MongoError.invalidNSURL(url: url)
        }
        
        var authentication: (username: String, password: String, against: String)? = nil
        
        let path = url.path ?? "admin"
        
        if let user = url.user, let pass = url.password {
            authentication = (username: user, password: pass, against: path)
        }
        
        #if !swift(>=3.0)
            let port: UInt16 = UInt16(url.port?.shortValue ?? 27017)
        #else
            let port: UInt16 = UInt16(url.port?.intValue ?? 27017)
        #endif
        
        try self.init(at: host, port: port, using: authentication, using: tcpDriver, automatically: connecting)
    }
    
    /// Sets up the `Server` to connect to the specified URL.
    /// The `mongodb://` scheme is required as well as the host. Optionally youc an provide ausername + password. And if no port is specified "27017" is used.
    /// You can provide an alternative TCP Driver that complies to `MongoTCP`.
    /// This Server doesn't connect automatically. You need to either use the `connect` function yourself or specify the `automatically` parameter to be true.
    ///
    /// - parameter url: The MongoDB connection String.
    /// - parameter using: The TCP Driver to be used to connect to the server. Recommended to change to an SSL supporting socket when connnecting over the public internet.
    /// - parameter automatically: Whether to connect automatically
    ///
    /// - throws: Throws when we can't connect automatically, when the scheme/host is invalid and when we can't connect automatically
    public convenience init(_ uri: String, using tcpDriver: MongoTCP.Type = Socks.TCPClient.self, automatically connecting: Bool = true) throws {
        guard let url = NSURL(string: uri) else {
            throw MongoError.invalidURI(uri: uri)
        }
        
        try self.init(url, using: tcpDriver, automatically: connecting)
    }
    
    /// Sets up the `Server` to connect to the specified location.`Server`
    /// You need to provide a host as IP address or as a hostname recognized by the client's DNS.
    /// - parameter at: The hostname/IP address of the MongoDB server
    /// - parameter port: The port we'll connect on. Defaults to 27017
    /// - parameter authentication: The optional authentication details we'll use when connecting to the server
    /// - parameter automatically: Connect automatically
    ///
    /// - throws: When we can’t connect automatically, when the scheme/host is invalid and when we can’t connect automatically
    public init(at host: String, port: UInt16 = 27017, using authentication: (username: String, password: String, against: String)? = nil, using tcpDriver: MongoTCP.Type = Socks.TCPClient.self, automatically connecting: Bool = false) throws {
        self.tcpType = tcpDriver
        self.server = (host: host, port: port)
        
        self.authDetails = authentication
        
        if connecting {
            try self.connect()
        }
    }
    
    /// The database cache
    private var databaseCache: [String : Weak<Database>] = [:]
    
    /// Returns a `Database` instance referring to the database with the provided database name
    ///
    /// - parameter database: The database's name
    ///
    /// - returns: A database instance for the requested database
    public subscript (databaseName: String) -> Database {
        databaseCache.clean()
        
        let databaseName = replaceOccurrences(in: databaseName, where: ".", with: "")
        
        if let db = databaseCache[databaseName]?.value {
            return db
        }
        
        let db = Database(database: databaseName, at: self)
        
        do {
            if !isInitialized {
                let result = try db.isMaster()
                
                let batchSize = result["maxWriteBatchSize"].int32
                let minWireVersion = result["minWireVersion"].int32
                let maxWireVersion = result["maxWireVersion"].int32
                var maxMessageSizeBytes = result["maxMessageSizeBytes"].int32
                if maxMessageSizeBytes == 0 {
                    maxMessageSizeBytes = 48000000
                }
                
                serverData = (maxWriteBatchSize: batchSize, maxWireVersion: maxWireVersion, minWireVersion: minWireVersion, maxMessageSizeBytes: maxMessageSizeBytes)
                
            }
        } catch {}
        
        if let details = authDetails {
            do {
                let protocolVersion = serverData?.maxWireVersion ?? 0
                
                if protocolVersion >= 3 {
                    try db.authenticate(SASL: details)
                } else {
                    try db.authenticate(mongoCR: details)
                }
            } catch {
                db.isAuthenticated = false
            }
        }
        
        databaseCache[databaseName] = Weak(db)
        return db
    }
    
    /// Generates a messageID for the next Message to be sent to the server
    ///
    /// - returns: The newly created ID for your message
    internal func nextMessageID() -> Int32 {
        lastRequestID += 1
        return lastRequestID
    }
    
    /// Are we currently connected?
    public private(set) var isConnected = false
    
    /// Connects with the MongoDB Server using the given information in the initializer
    ///
    /// - throws: Unable to connect
    public func connect() throws {
        self.client = try tcpType.open(address: server.host, port: server.port)
        try background(backgroundLoop)
        isConnected = true
    }
    
    /// Receives response messages from the server and gives them to the callback closure
    /// After handling the response with the closure it removes the closure
    private func backgroundLoop() {
        do {
            try self.receive()
            
            // Handle callbacks, locks etc on the responses
            for response in incomingResponses {
                waitingForResponses[response.id]?.broadcast()
                responseHandlers[response.id]?(response.message)
            }
        } catch {
            // A receive failure is to be expected if the socket has been closed
            if self.isConnected {
                print("The MongoDB background loop encountered an error: \(error)")
            }
            
            return
        }
        
        do {
            try background(backgroundLoop)
        } catch {
            do {
                try disconnect()
            } catch { print("Careful. Backgroundloop is broken") }
        }
    }
    
    /// Disconnects from the MongoDB server
    ///
    /// - throws: Unable to disconnect
    public func disconnect() throws {
        try client?.close()
        
        isInitialized = false
        isConnected = false
    }
    
    /// Called by the server thread to handle MongoDB Wire messages
    ///
    /// - parameter bufferSize: The amount of bytes to fetch at a time
    ///
    /// - throws: Unable to receive or parse the reply
    private func receive(bufferSize: Int = 1024) throws {
        guard let client = client else {
            throw MongoError.notConnected
        }
        
        // TODO: Respect bufferSize
        let incomingBuffer: [Byte] = try client.receive()
        fullBuffer += incomingBuffer
        
        do {
            while fullBuffer.count >= 36 {
                let length = Int(try fromBytes(fullBuffer[0...3]) as Int32)
                
                guard length <= fullBuffer.count else {
                    // Ignore: Wait for more data
                    return
                }
                
                let responseData = fullBuffer[0..<length]*
                let responseId = try fromBytes(fullBuffer[8...11]) as Int32
                let reply = try Message.makeReply(from: responseData)
                
                incomingMutateLock.lock()
                incomingResponses.append((responseId, reply, Date()))
                incomingMutateLock.unlock()
                
                fullBuffer.removeSubrange(0..<length)
            }
        }
    }
    
    /// Waits until the server responded to the request with the provided ID.
    /// Waits until the timeout is reached and throws if this is the case.
    ///
    /// - parameter response: The response's ID that we're awaiting a reply for
    /// - parameter until: Until when we'll wait for a response
    ///
    /// - throws: Timeout reached or an internal MongoKitten error occured. In the second case, please file a ticket
    ///
    /// - returns: The reply
    internal func await(response requestId: Int32, until timeout: TimeInterval = 60) throws -> Message {
        #if os(Linux)
            let condition = Condition()
        #else
            let condition = NSCondition()
        #endif
        
        condition.lock()
        waitingForResponses[requestId] = condition
        
        if incomingResponses.index(where: { $0.id == requestId }) == nil {
            #if os(Linux)
                if condition.waitUntilDate(Date(timeIntervalSinceNow: timeout)) == false {
                    throw MongoError.timeout
                }
            #else
                if condition.wait(until: Date(timeIntervalSinceNow: timeout)) == false {
                    throw MongoError.timeout
                }
            #endif
        }
        
        condition.unlock()
        
        incomingMutateLock.lock()
        defer {
            incomingMutateLock.unlock()
        }
        
        let i = incomingResponses.index(where: { $0.id == requestId })
        
        if let index = i {
            return incomingResponses.remove(at: index).message
        }
        
        // If we get here, something is very, very wrong.
        throw MongoError.internalInconsistency
    }
    
    /// Sends a message to the server
    ///
    /// - parameter message: The message we're sending
    ///
    /// - throws: Unable to send the message over the socket
    ///
    /// - returns: The RequestID for this message that can be used to fetch the response
    @discardableResult @warn_unqualified_access
    internal func send(message msg: Message) throws -> Int32 {
        guard let client = client else {
            throw MongoError.notConnected
        }
        
        let messageData = try msg.generateData()
        
        try client.send(data: messageData)
        
        return msg.requestID
    }
    
    /// Provides a list of all existing databases along with basic statistics about them
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/listDatabases/#dbcmd.listDatabases
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func getDatabaseInfos() throws -> Document {
        let request: Document = ["listDatabases": 1]
        
        let reply = try self["admin"].execute(command: request)
        
        return try firstDocument(in: reply)
    }
    
    /// Returns all existing databases on this server. **Requires access to the `admin` database**
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: All databases
    public func getDatabases() throws -> [Database] {
        let infos = try getDatabaseInfos()
        guard let databaseInfos = infos["databases"].documentValue else {
            throw MongoError.commandError(error: "No database Document found")
        }
        
        var databases = [Database]()
        for case (_, let dbDef) in databaseInfos where dbDef.documentValue != nil {
            guard let name = dbDef["name"].stringValue else {
                throw MongoError.commandError(error: "No database name found")
            }
            
            databases.append(self[name])
        }
        
        return databases
    }
    
    /// Copies a database either from one mongod instance to the current mongod instance or within the current mongod
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/copydb/#dbcmd.copydb
    ///
    /// - parameter database: The database to copy
    /// - parameter otherDatabase: The other database
    /// - parameter user: The database's credentials
    /// - parameter remoteHost: The optional remote host to copy from
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func copy(database db: String, to otherDatabase: String, as user: (user: String, nonce: String, password: String)? = nil, at remoteHost: String? = nil, slaveOk: Bool? = nil) throws {
        var command: Document = [
                                    "copydb": .int32(1),
                                ]

        if let fromHost = remoteHost {
            command["fromhost"] = ~fromHost
        }

        command["fromdb"] = ~db
        command["todb"] = ~otherDatabase

        if let slaveOk = slaveOk {
            command["slaveOk"] = ~slaveOk
        }

        if let user = user {
            command["username"] = ~user.user
            command["nonce"] = ~user.nonce
            
            let passHash = MD5.calculate("\(user.user):mongo:\(user.password)").hexString
            let key = MD5.calculate("\(user.nonce)\(user.user)\(passHash))").hexString
            command["key"] = ~key
        }

        let reply = try self["admin"].execute(command: command)
        let response = try firstDocument(in: reply)

        guard response["ok"].int32 == 1 else {
            throw MongoError.commandFailure(error: response)
        }
    }

    /// Clones a database from the specified MongoDB Connection URI
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/shutdown/#dbcmd.clone
    ///
    /// - parameter url: The URL
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func clone(from url: NSURL) throws {
        #if os(Linux)
            let absoluteString = url.absoluteString
        #else
            guard let absoluteString = url.absoluteString else {
                throw MongoError.invalidNSURL(url: url)
            }
        #endif
        
        try clone(from: absoluteString)
    }

    /// Clones a database from the specified MongoDB Connection URI
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/clone/#dbcmd.clone
    ///
    /// - parameter url: The URL
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func clone(from url: String) throws {
        let command: Document = [
                                    "clone": ~url
                                    ]

        let reply = try self["admin"].execute(command: command)
        let response = try firstDocument(in: reply)
        
        guard response["ok"].int32 == 1 else {
            throw MongoError.commandFailure(error: response)
        }
    }
    
    /// Shuts down the MongoDB server
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/shutdown/#dbcmd.shutdown
    ///
    /// - parameter force: Force the s
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func shutdown(forced force: Bool? = nil) throws {
        var command: Document = [
                                    "shutdown": .int32(1)
        ]
        
        if let force = force {
            command["force"] = ~force
        }
        
        let response = try firstDocument(in: try self["$cmd"].execute(command: command))
        
        guard response["ok"].int32 == 1 else {
            throw MongoError.commandFailure(error: response)
        }
    }
    
    /// Flushes all pending writes serverside
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/fsync/#dbcmd.fsync
    ///
    /// - parameter async: Do we run this async?
    /// - parameter block: Do we block writing in the meanwhile?
    public func fsync(async asynchronously: Bool? = nil, blocking block: Bool? = nil) throws {
        var command: Document = [
                                    "fsync": .int32(1)
        ]
        
        if let async = asynchronously {
            command["async"] = ~async
        }

        if let block = block {
            command["block"] = ~block
        }
        
        let reply = try self["admin"].execute(command: command)
        let response = try firstDocument(in: reply)
        
        guard response["ok"].int32 == 1 else {
            throw MongoError.commandFailure(error: response)
        }
    }

    /// Gets the info from the user
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/usersInfo/#dbcmd.usersInfo
    ///
    /// - parameter user: The user's username
    /// - parameter database: The database to get the user from... otherwise uses admin
    /// - parameter showCredentials: Do you want to fetch the user's credentials
    /// - parameter showPrivileges: Do you want to fetch the user's privileges
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: The user's information (plus optionally the credentials and privileges)
    public func info(for user: String, inDatabase database: Database? = nil, showCredentials: Bool? = nil, showPrivileges: Bool? = nil) throws -> Document {
        var command: Document = [
                                     "usersInfo": ["user": ~user, "db": ~(database?.name ?? "admin")]
                                     ]
        
        if let showCredentials = showCredentials {
            command["showCredentials"] = ~showCredentials
        }
        
        if let showPrivileges = showPrivileges {
            command["showPrivileges"] = ~showPrivileges
        }
        
        let db = database ?? self["admin"]

        let document = try firstDocument(in: try db.execute(command: command))
        
        guard document["ok"].int32 == 1 else {
            throw MongoError.commandFailure(error: document)
        }
        
        guard let users = document["users"].documentValue else {
            throw MongoError.commandError(error: "No users found")
        }
        
        return users
    }
}

extension Server : CustomStringConvertible {
    /// A textual representation of this `Server`
    public var description: String {
        return "MongoKitten.Server<\(hostname)>"
    }
    
    /// This server's hostname
    internal var hostname: String {
        return "\(server.host):\(server.port)"
    }
}
