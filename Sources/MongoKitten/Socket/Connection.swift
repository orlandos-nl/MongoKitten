//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Schrodinger
import Foundation
import Dispatch
import MongoSocket

/// A connection to MongoDB
class Connection {
    /// The TCP socket
    let client: MongoTCP
    
    /// The received data TCP buffer
    let buffer = TCPBuffer()
    
    /// Whether this server supports write operations
    var writable = false
    
    /// This connection is authenticated against these DBs
    var authenticatedDBs: [String] = []
    
    /// Ran when closing
    var onClose: (()->())
    
    /// The host that's connected to
    let host: MongoHost
    
    /// The amount of current users
    var users: Int = 0
    
    /// The incoming temporary buffer
    var incomingBuffer = Bytes()

    /// The dispatch queue that this connection listens on
    private static let receiveQueue = DispatchQueue(label: "org.mongokitten.server.receiveQueue", attributes: .concurrent)
    
    /// The responses being waited for
    var waitingForResponses = [Int32: ManualPromise<ServerReply>]()
    
    /// A cache for incoming responses
    var incomingMutateLock = NSLock()
    
    /// Whether this client is still connected
    public var isConnected: Bool {
        return client.isConnected
    }
    
    /// Simply creates a new connection from existing data
    init(clientSettings: ClientSettings, writable: Bool, host: MongoHost, onClose: @escaping (()->())) throws {

        var options = [String:Any] ()
        if let sslSettings = clientSettings.sslSettings {
            options["sslEnabled"]  = sslSettings.enabled
            options["invalidCertificateAllowed"]  = sslSettings.invalidCertificateAllowed
            options["invalidHostNameAllowed"] = sslSettings.invalidHostNameAllowed
        } else {
            options["sslEnabled"]  = false
        }

        self.client = try MongoSocket(address: host.hostname, port: host.port, options: options)
        self.writable = writable
        self.onClose = onClose
        self.host = host
        
        Connection.receiveQueue.async(execute: backgroundLoop)
    }
    
    /// Authenticates this connection to a database
    ///
    /// - parameter db: The database to authenticate to
    ///
    /// - throws: Authentication error
    func authenticate(to db: Database) throws {
        if let details = db.server.clientSettings.credentials {
            do {
                switch details.authenticationMechanism {
                case .SCRAM_SHA_1:
                    try db.authenticate(SASL: details, usingConnection: self)
                case .MONGODB_CR:
                    try db.authenticate(mongoCR: details, usingConnection: self)
                default:
                    throw MongoError.unsupportedFeature("authentication Method \"\(details.authenticationMechanism.rawValue)\"")
                }
                
                self.authenticatedDBs.append(db.name)
            } catch { }
        }
    }
    
    /// Receives response messages from the server and gives them to the callback closure
    /// After handling the response with the closure it removes the closure
    fileprivate func backgroundLoop() {
        do {
            try self.receive()
        } catch {
            // A receive failure is to be expected if the socket has been closed
            incomingMutateLock.lock()
            if self.isConnected {
                log.fatal("The MongoKitten background loop encountered an error and has stopped: \(error)")
                log.fatal("Please file a report on https://github.com/openkitten/mongokitten")
            }
            incomingMutateLock.unlock()
            
            return
        }
        
        Connection.receiveQueue.async(execute: backgroundLoop)
    }
    
    /// Closes this connection
    func close() {
        _ = try? client.close()
        onClose()
    }
    
    /// Called by the server thread to handle MongoDB Wire messages
    ///
    /// - parameter bufferSize: The amount of bytes to fetch at a time
    ///
    /// - throws: Unable to receive or parse the reply
    private func receive(bufferSize: Int = 1024) throws {
        try client.receive(into: &incomingBuffer)
        buffer.data += incomingBuffer
        
        while buffer.data.count >= 36 {
            let length = Int(buffer.data[0...3].makeInt32())
            
            guard length <= buffer.data.count else {
                // Ignore: Wait for more data
                return
            }
            
            let responseData = buffer.data[0..<length]*
            let responseId = buffer.data[8...11].makeInt32()
            let reply = try Message.makeReply(from: responseData)
            
            defer { waitingForResponses[responseId] = nil }
            
            if let promise = waitingForResponses[responseId] {
                _ = try promise.complete(reply)
            }
            
            buffer.data.removeSubrange(0..<length)
        }
    }
}
