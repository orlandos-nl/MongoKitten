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

@_exported import C7
@_exported import BSON

import Foundation
import TCP

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// This file contains the low level code. This code is synchronous and is used by the async client API. //
//////////////////////////////////////////////////////////////////////////////////////////////////////////


/// A ResponseHandler is a closure that receives a MongoReply to process it
/// It's internal because ReplyMessages are an internal struct that is used for direct communication with MongoDB only
internal typealias ResponseHandler = ((reply: Message) -> Void)

/// A server object is the core of MongoKitten. From this you can get databases which can provide you with collections from where you can do actions
public class Server {
    /// Is the socket connected?
    public var connected: Bool { return !(stream?.closed ?? true) }
    
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
    
    /// C7 compliant Streaming Client bound to the MongoDB Server
    private var client: StreamClient

    /// C7 compliant Stream connected to the MongoDB Server
    private var stream: Stream?
    
    /// Did we initialize?
    private var isInitialized = false
    
    /// The background thread for sending and receiving data
    private let backgroundQueue = backgroundThread()
    
    internal private(set) var serverData: (maxWriteBatchSize: Int32, maxWireVersion: Int32, minWireVersion: Int32, maxMessageSizeBytes: Int32)?
    
    /// Initializes a MongoDB Client instance on a given connection
    /// - parameter client: The Stream Client connected to the MongoDB Serer
    /// - parameter authentication: The optional Login Credentials for the account on the server
    /// - parameter autoConnect: Whether we automatically connect
    public init(_ client: StreamClient, using authentication: (username: String, password: String)? = nil, automatically connecting: Bool = false) throws {
        self.client = client

        self.authDetails = authentication
        
        if connecting {
            try self.connect()
        }
    }
    
    /// Initializes a MongoDB Client Instance on a given port with a given host
    /// - parameter host: The host we'll connect to
    /// - parameter port: The port we'll connect on
    /// - parameter authentication: The optional authentication details we'll use when connecting to the server
    public convenience init(host: String, at port: Int = 27017, using authentication: (username: String, password: String)? = nil, automatically connecting: Bool = false) throws {
        let client: StreamClient = try TCPStreamClient(address: host, port: port)

        try self.init(client, using: authentication, automatically: connecting)
    }
    
    /// This subscript returns a Database struct given a String
    /// - parameter database: The database's name
    /// - returns: A database instance for the requested database
    public subscript (database: String) -> Database {
        let database = database.replacingOccurrences(of: ".", with: "")
        
        let db = Database(database: database, at: self)
        
        do {
            if !isInitialized {
                let result = try db.isMaster()
                
                if let batchSize = result["maxWriteBatchSize"]?.int32Value, let minWireVersion = result["minWireVersion"]?.int32Value, let maxWireVersion = result["maxWireVersion"]?.int32Value {
                    let maxMessageSizeBytes = result["maxMessageSizeBytes"]?.int32Value ?? 48000000
                    
                    serverData = (maxWriteBatchSize: batchSize, maxWireVersion: maxWireVersion, minWireVersion: minWireVersion, maxMessageSizeBytes: maxMessageSizeBytes)
                    
                    isInitialized = true
                }
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
    internal func nextMessageID() -> Int32 {
        lastRequestID += 1
        return lastRequestID
    }
    
    /// Connects with the MongoDB Server using the given information in the initializer
    public func connect() throws {
        if self.connected {
            throw MongoError.MongoDatabaseAlreadyConnected
        }
        
        self.stream = try client.connect()
        Background(backgroundQueue, backgroundLoop)
    }
    
    private func backgroundLoop() {
        guard self.connected else { return }
        
        do {
            try self.receive()
            
            // Handle callbacks, locks etc on the responses
            for response in incomingResponses {
                waitingForResponses[response.id]?.broadcast()
                responseHandlers[response.id]?(reply: response.message)
            }
        } catch {
            // A receive failure is to be expected if the socket has been closed
            if self.connected {
                print("The MongoDB background loop encountered an error: \(error)")
            } else {
                return
            }
        }
        
        Background(backgroundQueue, backgroundLoop)
    }
    
    /// Throws an error if the database is not connected yet
    private func assertConnected() throws {
        guard connected else {
            throw MongoError.MongoDatabaseNotYetConnected
        }
    }
    
    /// Disconnects from the MongoDB server
    public func disconnect() throws {
        try assertConnected()
        guard let success = stream?.close() where success else {
            throw MongoError.CannotDisconnect
        }
        
        isInitialized = false
    }
    
    /// Called by the server thread to handle MongoDB Wire messages
    private func receive(bufferSize: Int32 = 1024) throws {
        guard let result = try stream?.receive() else {
            throw MongoError.MongoDatabaseNotYetConnected
        }

        fullBuffer += result
        
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
    
    internal func await(response requestId: Int32, with timeout: NSTimeInterval = 10) throws -> Message {
        let condition = NSCondition()
        condition.lock()
        waitingForResponses[requestId] = condition
        
        if condition.wait(until: NSDate(timeIntervalSinceNow: timeout)) == false {
            throw MongoError.Timeout
        }
        
        condition.unlock()
        
        for (index, response) in incomingResponses.enumerated() {
            if response.id == requestId {
                return incomingResponses.remove(at: index).message
            }
        }
        
        // If we get here, something is very, very wrong.
        throw MongoError.InternalInconsistency
    }
    
    /**
     Send given message to the server.
     
     This method executes on the thread of the caller and returns when done.
     
     - parameter message: A message to send to  the server
     
     - returns: The request ID of the sent message
     */
    internal func send(message message: Message) throws -> Int32 {
        try assertConnected()
        
        let messageData = try message.generateData()
        
        try stream?.send(messageData)
        
        return message.requestID
    }
}