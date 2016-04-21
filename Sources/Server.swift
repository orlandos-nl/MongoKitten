//
//  NewDatabase.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 24/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

@_exported import BSON

import Foundation

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// This file contains the low level code. This code is synchronous and is used by the async client API. //
//////////////////////////////////////////////////////////////////////////////////////////////////////////


/// A ResponseHandler is a closure that receives a MongoReply to process it
/// It's internal because ReplyMessages are an internal struct that is used for direct communication with MongoDB only
internal typealias ResponseHandler = ((reply: Message) -> Void)

/// A server object is the core of MongoKitten. From this you can get databases which can provide you with collections from where you can do actions
public final class Server {
    /// The authentication details that are used to connect with the MongoDB server
    private let authDetails: (username: String, password: String)?
    
    /// The last Request we sent.. -1 if no request was sent
    internal var lastRequestID: Int32 = -1
    
    /// The full buffer of received bytes from MongoDB
    internal var fullBuffer = [Byte]()
    
    /// A cache for incoming responses
    private var incomingResponses = [(id: Int32, message: Message, date: NSDate)]()
    
    /// Contains a map from an ID to a handler. The handlers handle the `incomingResponses`
    private var responseHandlers = [Int32:ResponseHandler]()
    
    private var waitingForResponses = [Int32:NSCondition]()
    
    /// TCP Socket bound to the MongoDB Server
    private var client: MongoTCP?
    public let tcpType: MongoTCP.Type
    
    /// Did we initialize?
    private var isInitialized = false
    
    /// The server's hostname/IP and port to connect to
    public let server: (host: String, port: UInt16)
    
    internal private(set) var serverData: (maxWriteBatchSize: Int32, maxWireVersion: Int32, minWireVersion: Int32, maxMessageSizeBytes: Int32)?
    
    // Initializes a MongoDB Client instance on a given connection
    // - parameter client: The Stream Client connected to the MongoDB Serer
    // - parameter authentication: The optional Login Credentials for the account on the server
    // - parameter autoConnect: Whether we automatically connect
    //    public init(_ client: StreamClient, using authentication: (username: String, password: String)? = nil, automatically connecting: Bool = false) throws {
    //        self.client = client
    //
    //        self.authDetails = authentication
    //
    //        if connecting {
    //            try self.connect()
    //        }
    //    }
    
    public convenience init(_ url: NSURL, using tcpDriver: MongoTCP.Type = CSocket.self, automatically connecting: Bool = true) throws {
        #if os(Linux)
            let scheme = url.scheme ?? ""
        #else
            let scheme = url.scheme
        #endif
        
        guard scheme.lowercased() == "mongodb", let host = url.host else {
            throw MongoError.InvalidNSURL(url: url)
        }
        
        var authentication: (username: String, password: String)? = nil
        
        if let user = url.user, pass = url.password {
            authentication = (username: user, password: pass)
        }
        
        #if os(Linux)
            let port: UInt16 = UInt16(url.port?.shortValue ?? 27017)
        #else
            let port: UInt16 = UInt16(url.port?.int16Value ?? 27017)
        #endif
        
        try self.init(at: host, port: port, using: authentication, automatically: connecting, using: tcpDriver)
    }
    
    public convenience init(_ uri: String, using tcpDriver: MongoTCP.Type = CSocket.self, automatically connecting: Bool = true) throws {
        guard let url = NSURL(string: uri) else {
            throw MongoError.InvalidURI(uri: uri)
        }
        
        try self.init(url, using: tcpDriver, automatically: connecting)
    }
    
    /// Initializes a MongoDB Client Instance on a given port with a given host
    /// - parameter at: The host we'll connect to
    /// - parameter port: The port we'll connect on
    /// - parameter authentication: The optional authentication details we'll use when connecting to the server
    /// - parameter automatically: Connect automatically
    public init(at host: String, port: UInt16 = 27017, using authentication: (username: String, password: String)? = nil, using tcpDriver: MongoTCP.Type = CSocket.self, automatically connecting: Bool = false) throws {
        self.tcpType = tcpDriver
        self.server = (host: host, port: port)
        
        self.authDetails = authentication
        
        if connecting {
            try self.connect()
        }
    }
    
    /// This subscript returns a Database struct given a String
    /// - parameter database: The database's name
    /// - returns: A database instance for the requested database
    public subscript (database: String) -> Database {
        let database = replaceOccurrences(in: database, where: ".", with: "")
        
        let db = Database(database: database, at: self)
        
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
        
        return db
    }
    
    /// Generates a messageID for the next Message
    /// - returns: The newly created ID for your message
    internal func nextMessageID() -> Int32 {
        lastRequestID += 1
        return lastRequestID
    }
    
    public private(set) var isConnected = false
    
    /// Connects with the MongoDB Server using the given information in the initializer
    public func connect() throws {
        self.client = try tcpType.open(address: server.host, port: server.port)
        try Background(function: backgroundLoop)
        isConnected = true
    }
    
    private func backgroundLoop() {
        do {
            try self.receive()
            
            // Handle callbacks, locks etc on the responses
            for response in incomingResponses {
                waitingForResponses[response.id]?.broadcast()
                responseHandlers[response.id]?(reply: response.message)
            }
        } catch {
            // A receive failure is to be expected if the socket has been closed
            //            if self.isConnected {
            //                print("The MongoDB background loop encountered an error: \(error)")
            //            } else {
            //                return
            //            }
            return
        }
        
        do {
            try Background(function: backgroundLoop)
        } catch {
            do {
                try disconnect()
            } catch { print("Careful. Backgroundloop is broken") }
        }
    }
    
    /// Disconnects from the MongoDB server
    public func disconnect() throws {
        try client?.close()
        
        isInitialized = false
        isConnected = false
    }
    
    /// Called by the server thread to handle MongoDB Wire messages
    /// - parameter bufferSize: The amount of bytes to fetch at a time
    private func receive(bufferSize: Int = 1024) throws {
        guard let client = client else {
            throw MongoError.NotConnected
        }
        
        // TODO: Respect bufferSize
        let incomingBuffer: [Byte] = try client.receive()
        fullBuffer += incomingBuffer
        
        do {
            while fullBuffer.count >= 36 {
                guard let length: Int = Int(try Int32.instantiate(bsonData: fullBuffer[0...3]*)) else {
                    throw DeserializationError.ParseError
                }
                
                guard length <= fullBuffer.count else {
                    // Ignore: Wait for more data
                    return
                }
                
                let responseData = fullBuffer[0..<length]*
                let responseId = try Int32.instantiate(bsonData: fullBuffer[8...11]*)
                let reply = try Message.makeReply(from: responseData)
                
                incomingResponses.append((responseId, reply, NSDate()))
                
                fullBuffer.removeSubrange(0..<length)
            }
        }
    }
    
    /// Awaits until a set amount of time for response of the server
    /// - parameter response: The response's ID that we're awaiting a reply for
    /// - parameter until: Until when we'll wait for a response
    /// - returns: The reply
    internal func await(response requestId: Int32, until timeout: NSTimeInterval = 60) throws -> Message {
        let condition = NSCondition()
        condition.lock()
        waitingForResponses[requestId] = condition
        
        #if os(Linux)
            if condition.waitUntilDate(NSDate(timeIntervalSinceNow: timeout)) == false {
                throw MongoError.Timeout
            }
        #else
            if condition.wait(until: NSDate(timeIntervalSinceNow: timeout)) == false {
                throw MongoError.Timeout
            }
        #endif
        
        condition.unlock()
        
        let i = incomingResponses.index(where: { $0.id == requestId })
        
        if let index = i {
            return incomingResponses.remove(at: index).message
        }
        
        // If we get here, something is very, very wrong.
        throw MongoError.InternalInconsistency
    }
    
    /// Sends a message's data to the server
    /// - parameter message: The message we're sending
    /// - returns: The RequestID for this message
    internal func send(message: Message) throws -> Int32 {
        guard let client = client else {
            throw MongoError.NotConnected
        }
        
        let messageData = try message.generateData()
        
        try client.send(data: messageData)
        
        return message.requestID
    }
    
    /// Provides a list of all existing databases along with basic statistics about them.
    public func getDatabaseInfos() throws -> Document {
        let request: Document = ["listDatabases": 1]
        
        let reply = try self["admin"].execute(command: request)
        
        return try firstDocument(in: reply)
    }
    
    /// Returns all existing databases on this server. **Requires access to the `admin` database**
    public func getDatabases() throws -> [Database] {
        let infos = try getDatabaseInfos()
        guard let databaseInfos = infos["databases"].documentValue else {
            throw MongoError.CommandFailure
        }
        
        var databases = [Database]()
        for case (_, let dbDef) in databaseInfos where dbDef.documentValue != nil {
            guard let name = dbDef["name"].stringValue else {
                throw MongoError.CommandFailure
            }
            
            databases.append(self[name])
        }
        
        return databases
    }
}