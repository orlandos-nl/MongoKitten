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

#if MongoTLS
    import TLS
    public let DefaultTCPClient: MongoTCP.Type = TLS.Socket.self
#else
    public let DefaultTCPClient: MongoTCP.Type = Socks.TCPClient.self
#endif

@_exported import BSON

import Foundation
import CryptoKitten
import Dispatch

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// This file contains the low level code. This code is synchronous and is used by the async client API. //
//////////////////////////////////////////////////////////////////////////////////////////////////////////


/// A ResponseHandler is a closure that receives a MongoReply to process it
/// It's internal because ReplyMessages are an internal struct that is used for direct communication with MongoDB only
internal typealias ResponseHandler = ((Message) -> Void)

/// A server object is the core of MongoKitten as it's used to communicate to the server.
/// You can select a `Database` by subscripting an instance of this Server with a `String`.
public final class Server {
    
    class Connection {
        let client: MongoTCP
        let buffer = TCPBuffer()
        var used = false
        public fileprivate(set) var isConnected = true
        
        init(client: MongoTCP) {
            self.client = client
            Connection.receiveQueue.async(execute: backgroundLoop)
        }
        
        private static let receiveQueue = DispatchQueue(label: "org.mongokitten.server.receiveQueue", attributes: .concurrent)
        
        fileprivate var waitingForResponses = [Int32:(Message)->()]()
        
        /// A cache for incoming responses
        fileprivate var incomingMutateLock = NSLock()
        
        /// Receives response messages from the server and gives them to the callback closure
        /// After handling the response with the closure it removes the closure
        fileprivate func backgroundLoop() {
            do {
                try self.receive()
            } catch {
                // A receive failure is to be expected if the socket has been closed
                incomingMutateLock.lock()
                if self.isConnected {
                    print("The MongoKitten background loop encountered an error and has stopped: \(error)")
                    print("Please file a report on https://github.com/openkitten/mongokitten")
                }
                incomingMutateLock.unlock()
                
                return
            }
            
            Connection.receiveQueue.async(execute: backgroundLoop)
        }
        
        /// Called by the server thread to handle MongoDB Wire messages
        ///
        /// - parameter bufferSize: The amount of bytes to fetch at a time
        ///
        /// - throws: Unable to receive or parse the reply
        private func receive(bufferSize: Int = 1024) throws {
            // TODO: Respect bufferSize
            let incomingBuffer: [UInt8] = try client.receive()
            buffer.data += incomingBuffer
            
            while buffer.data.count >= 36 {
                let length = Int(try fromBytes(buffer.data[0...3]) as Int32)
                
                guard length <= buffer.data.count else {
                    // Ignore: Wait for more data
                    return
                }
                
                let responseData = buffer.data[0..<length]*
                let responseId = try fromBytes(buffer.data[8...11]) as Int32
                let reply = try Message.makeReply(from: responseData)
                
                if let closure = waitingForResponses[responseId] {
                    closure(reply)
                    waitingForResponses[responseId] = nil
                } else {
                    print("WARNING: Unhandled response with id \(responseId)")
                }
                
                buffer.data.removeSubrange(0..<length)
            }
        }
    }
    
    public var cursorErrorHandler: ((Error)->()) = { doc in
        print(doc)
    }
    
    /// The authentication details that are used to connect with the MongoDB server
    internal let authDetails: (username: String, password: String, against: String)?
    
    /// The last Request we sent.. -1 if no request was sent
    internal var lastRequestID: Int32 = -1
    
    /// `MongoTCP` Socket bound to the MongoDB Server
    private var connections = [Connection]()
    
    /// `MongoTCP` class to use for clients
    public let tcpType: MongoTCP.Type
    
    /// Semaphore to use for safely managing connections
    private let connectionPoolSemaphore: DispatchSemaphore
    
    /// Lock to prevent multiple writes to/from the connections.
    private let connectionPoolLock = NSRecursiveLock()
    
    /// Keeps track of the connections
    private var currentConnections = 0, maximumConnections = 1
    
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
    public convenience init(mongoURL url: NSURL, usingTcpDriver tcpDriver: MongoTCP.Type = DefaultTCPClient, maxConnections: Int = 10) throws {
        guard let scheme = url.scheme, let host = url.host , scheme.lowercased() == "mongodb" else {
            throw MongoError.invalidNSURL(url: url)
        }
        
        var authentication: (username: String, password: String, against: String)? = nil
        
        let path = url.path ?? "admin"
        
        if let user = url.user?.removingPercentEncoding, let pass = url.password?.removingPercentEncoding {
            authentication = (username: user, password: pass, against: path)
        }
        
        let port: UInt16 = UInt16(url.port?.intValue ?? 27017)
        
        try self.init(hostname: host, port: port, authenticatedAs: authentication, usingTcpDriver: tcpDriver, maxConnections: maxConnections)
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
    public convenience init(mongoURL uri: String, usingTcpDriver tcpDriver: MongoTCP.Type = DefaultTCPClient, maxConnections: Int = 10) throws {
        guard let url = NSURL(string: uri) else {
            throw MongoError.invalidURI(uri: uri)
        }
        
        try self.init(mongoURL: url, usingTcpDriver: tcpDriver, maxConnections: maxConnections)
    }
    
    /// Sets up the `Server` to connect to the specified location.`Server`
    /// You need to provide a host as IP address or as a hostname recognized by the client's DNS.
    /// - parameter at: The hostname/IP address of the MongoDB server
    /// - parameter port: The port we'll connect on. Defaults to 27017
    /// - parameter authentication: The optional authentication details we'll use when connecting to the server
    /// - parameter automatically: Connect automatically
    ///
    /// - throws: When we can’t connect automatically, when the scheme/host is invalid and when we can’t connect automatically
    public init(hostname host: String, port: UInt16 = 27017, authenticatedAs authentication: (username: String, password: String, against: String)? = nil, usingTcpDriver tcpDriver: MongoTCP.Type = DefaultTCPClient, maxConnections: Int = 10) throws {
        self.tcpType = tcpDriver
        self.server = (host: host, port: port)
        self.maximumConnections = maxConnections
        self.authDetails = authentication
        
        self.connectionPoolSemaphore = DispatchSemaphore(value: maxConnections)
    }
    
    private func makeConnection() throws -> Connection {
        return Connection(client: try tcpType.open(address: server.host, port: server.port))
    }
    
    internal func reserveConnection() throws -> Connection {
        guard let connection = self.connections.first(where: { !$0.used }) else {
            self.connectionPoolLock.lock()
            guard currentConnections < maximumConnections else {
                let timeout = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 10_000_000_000)
                
                guard case .success = self.connectionPoolSemaphore.wait(timeout: timeout) else {
                    throw MongoError.timeout
                }
                
                return try reserveConnection()
            }
            
            let connection = try makeConnection()
            connection.used = true
            
            connections.append(connection)
            self.connectionPoolLock.unlock()
            
            return connection
        }
        
        connection.used = true
        
        return connection
    }
    
    internal func returnConnection(_ connection: Connection) {
        self.connectionPoolLock.lock()
        
        defer {
            self.connectionPoolLock.unlock()
            self.connectionPoolSemaphore.signal()
        }
        
        connection.used = false
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
        
        let databaseName = databaseName.replacingOccurrences(of: ".", with: "")
        
        if let db = databaseCache[databaseName]?.value {
            return db
        }
        
        let db = Database(database: databaseName, at: self)
        
        connect: do {
            if !isInitialized {
                let result = try db.isMaster()
                
                guard let batchSize = result["maxWriteBatchSize"]?.int32, let minWireVersion = result["minWireVersion"]?.int32, let maxWireVersion = result["maxWireVersion"]?.int32 else {
                    continue connect
                }
                
                var maxMessageSizeBytes = result["maxMessageSizeBytes"]?.int32 ?? 0
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
    
    private let messageMutationQueue = DispatchQueue(label: "org.mongokitten.server.messageIncrementQueue")
    /// Generates a messageID for the next Message to be sent to the server
    ///
    /// - returns: The newly created ID for your message
    internal func nextMessageID() -> Int32 {
        var id: Int32 = 0
        messageMutationQueue.sync {
            lastRequestID += 1
            id = lastRequestID
        }
        return id
    }
    
    /// Are we currently connected?
    public var isConnected: Bool {
        for connection in connections where !connection.isConnected {
            return false
        }
        
        if connections.count == 0 {
            guard let connection = try? reserveConnection() else {
                return false
            }
            
            defer {
                returnConnection(connection)
            }
            
            return connection.isConnected
        }
        
        return true
    }
    
    /// Disconnects from the MongoDB server
    ///
    /// - throws: Unable to disconnect
    public func disconnect() throws {
        connectionPoolLock.lock()
        isInitialized = false
        
        for db in self.databaseCache {
            db.value.value?.isAuthenticated = false
        }
        
        while let connection = connections.popLast() {
            connection.isConnected = false
            try connection.client.close()
        }
        
        connections = []
        currentConnections = 0
        
        connectionPoolLock.unlock()
    }
    

    /// Sends a message to the server and waits until the server responded to the request.
    ///
    /// - parameter message: The message we're sending
    /// - parameter timeout: Timeout, in seconds
    ///
    /// - throws: Timeout reached or an internal MongoKitten error occured. In the second case, please file a ticket
    ///
    /// - returns: The reply from the server
    @discardableResult @warn_unqualified_access
    internal func sendAndAwait(message msg: Message, overConnection connection: Connection, timeout: TimeInterval = 60) throws -> Message {
        let requestId = msg.requestID
        
        let semaphore = DispatchSemaphore(value: 0)
        
        connection.incomingMutateLock.lock()
        
        var reply: Message? = nil
        connection.waitingForResponses[requestId] = { message in
            reply = message
            semaphore.signal()
        }
        
        connection.incomingMutateLock.unlock()
        
        let messageData = try msg.generateData()
        
        try connection.client.send(data: messageData)

        guard semaphore.wait(timeout: DispatchTime.now() + timeout) == .success else {
            connection.incomingMutateLock.lock()
            connection.waitingForResponses[requestId] = nil
            connection.incomingMutateLock.unlock()
            throw MongoError.timeout
        }
        
        guard let theReply = reply else {
            // If we get here, something is very, very wrong.
            throw MongoError.internalInconsistency
        }
        
        return theReply
    }
    
    /// Sends a message to the server
    ///
    /// - parameter message: The message we're sending
    ///
    /// - throws: Unable to send the message over the socket
    ///
    /// - returns: The RequestID for this message that can be used to fetch the response
    @discardableResult @warn_unqualified_access
    internal func send(message msg: Message, overConnection connection: Connection) throws -> Int32 {
        let messageData = try msg.generateData()
        
        try connection.client.send(data: messageData)
        
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
        guard let databaseInfos = infos["databases"] as? Document else {
            throw MongoError.commandError(error: "No database Document found")
        }
        
        var databases = [Database]()
        for case (_, let dbDef) in databaseInfos {
            guard let dbDef = dbDef as? Document, let name = dbDef["name"] as? String else {
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
                                    "copydb": Int32(1),
                                ]

        if let fromHost = remoteHost {
            command["fromhost"] = fromHost
        }

        command["fromdb"] = db
        command["todb"] = otherDatabase

        if let slaveOk = slaveOk {
            command["slaveOk"] = slaveOk
        }

        if let user = user {
            command["username"] = user.user
            command["nonce"] = user.nonce
            
            let passHash = MD5.hash([UInt8]("\(user.user):mongo:\(user.password)".utf8)).hexString
            let key = MD5.hash([UInt8]("\(user.nonce)\(user.user)\(passHash))".utf8)).hexString
            command["key"] = key
        }

        let reply = try self["admin"].execute(command: command)
        let response = try firstDocument(in: reply)

        guard response["ok"] == 1 else {
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
                                    "clone": url
                                    ]

        let reply = try self["admin"].execute(command: command)
        let response = try firstDocument(in: reply)
        
        guard response["ok"] == 1 else {
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
                                    "shutdown": Int32(1)
        ]
        
        if let force = force {
            command["force"] = force
        }
        
        let response = try firstDocument(in: try self["$cmd"].execute(command: command))
        
        guard response["ok"] == 1 else {
            throw MongoError.commandFailure(error: response)
        }
    }
    
    /// Flushes all pending writes serverside
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/fsync/#dbcmd.fsync
    ///
    /// - parameter async: If true, dont block the server until the operation is finished
    /// - parameter block: Do we block writing in the meanwhile?
    public func fsync(async asynchronously: Bool? = nil, blocking block: Bool? = nil) throws {
        var command: Document = [
                                    "fsync": Int32(1)
        ]
        
        if let async = asynchronously {
            command["async"] = async
        }

        if let block = block {
            command["block"] = block
        }
        
        let reply = try self["admin"].execute(command: command)
        let response = try firstDocument(in: reply)
        
        guard response["ok"] == 1 else {
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
    public func getUserInfo(forUserNamed user: String, inDatabase database: Database? = nil, showCredentials: Bool? = nil, showPrivileges: Bool? = nil) throws -> Document {
        var command: Document = [
                                     "usersInfo": ["user": user, "db": (database?.name ?? "admin")] as Document
                                     ]
        
        if let showCredentials = showCredentials {
            command["showCredentials"] = showCredentials
        }
        
        if let showPrivileges = showPrivileges {
            command["showPrivileges"] = showPrivileges
        }
        
        let db = database ?? self["admin"]

        let document = try firstDocument(in: try db.execute(command: command))
        
        guard document["ok"] == 1 else {
            throw MongoError.commandFailure(error: document)
        }
        
        guard let users = document["users"] as? Document else {
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

extension Server: Sequence {
    public func makeIterator() -> AnyIterator<Database> {
        guard var databases = try? self.getDatabases() else {
            return AnyIterator { nil }
        }
        
        return AnyIterator {
            return databases.count > 0 ? databases.removeFirst() : nil
        }
    }
}
