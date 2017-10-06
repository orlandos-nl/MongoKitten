//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Async
import Foundation
import Dispatch
import MongoSocket

/// A connection to MongoDB
class Connection {
    /// The TCP socket
    fileprivate var client: MongoTCP!
    
    /// Whether this server supports write operations
    var writable = false
    
    /// This connection is authenticated against these DBs
    var authenticated = false
    
    /// Ran when closing
    var onClose: (()->())
    
    /// The host that's connected to
    let host: MongoHost
    
    /// The amount of current users
    var users: Int = 0
    
    /// The currently constructing reply
    var nextReply = ServerReplyPlaceholder()
    
    /// Handles mutations the response buffer
    internal static let mutationsQueue = DispatchQueue(label: "org.mongokitten.server.responseQueue", qos: DispatchQoS.userInteractive)
    
    /// The responses being waited for
    var waitingForResponses = [Int32: Promise<ServerReply>]()
    
    /// Whether this client is still connected
    public var isConnected: Bool {
        return Connection.mutationsQueue.sync { self.client.isConnected }
    }
    
    /// Simply creates a new connection from existing data
    init(clientSettings: ClientSettings, writable: Bool, host: MongoHost, onClose: @escaping (()->())) throws {
        var options = [String:Any] ()
        if let sslSettings = clientSettings.sslSettings {
            options["sslEnabled"]  = sslSettings.enabled
            options["invalidCertificateAllowed"]  = sslSettings.invalidCertificateAllowed
            options["invalidHostNameAllowed"] = sslSettings.invalidHostNameAllowed
            options["CAFile"] = sslSettings.CAFilePath
        } else {
            options["sslEnabled"]  = false
        }
        
        self.writable = writable
        self.onClose = onClose
        self.host = host

        self.client = try clientSettings.TCPClient.init(address: host.hostname, port: host.port, options: options, onRead: self.onRead, onError: { _ in
            self.close()
        })
    }
    
    /// Authenticates this connection to a database
    ///
    /// - parameter db: The database to authenticate to
    ///
    /// - throws: Authentication error
    func authenticate(to db: Database) throws -> Future<Void> {
        if let details = db.server.clientSettings.credentials {
            let db = db.server[details.database ?? db.name]
            
            switch details.authenticationMechanism {
            case .SCRAM_SHA_1:
                return try self.authenticate(SASL: details, to: db)
            case .MONGODB_CR:
                return try self.authenticate(mongoCR: details, to: db)
            case .MONGODB_X509:
                return try self.authenticateX509(subject: details.username, to: db)
            default:
                throw MongoError.unsupportedFeature("authentication Method \"\(details.authenticationMechanism.rawValue)\"")
            }
            
            self.authenticated = true
        }
    }
    
    /// Closes this connection
    func close() {
        _ = try? client.close()
        onClose()
        
        Connection.mutationsQueue.sync {
            for (_, callback) in self.waitingForResponses {
                callback.fail(MongoError.notConnected)
            }
            
            self.waitingForResponses = [:]
        }
    }
    
    var pastReplyLeftovers = Data()
    
    private func onRead(at pointer: UnsafeMutablePointer<UInt8>, withLengthOf length: Int) {
        func checkComplete() {
            if nextReply.isComplete {
                defer { nextReply = ServerReplyPlaceholder() }
                
                guard let reply = nextReply.construct() else {
                    return
                }
                
                _ = try? Connection.mutationsQueue.sync {
                    if let promise = waitingForResponses[reply.responseTo] {
                        try promise.complete { reply }
                        waitingForResponses[reply.responseTo] = nil
                    }
                }
                
                if nextReply.unconsumed.count > 0 {
                    pastReplyLeftovers.append(contentsOf: nextReply.unconsumed)
                }
                
                return
            }
            
            return
        }
        
        var pointer = pointer
        var length = length
        
        while true {
            while pastReplyLeftovers.count > 0 {
                pastReplyLeftovers.withUnsafeMutableBytes { (pointer: UnsafeMutablePointer<UInt8>) in
                    let consumed = nextReply.process(consuming: pointer, withLengthOf: pastReplyLeftovers.count)
                    
                    pastReplyLeftovers.removeFirst(consumed)
                    
                    checkComplete()
                }
            }

            let consumed = nextReply.process(consuming: pointer, withLengthOf: length)

            checkComplete()

            guard consumed < length else {
                return
            }
            
            pointer = pointer.advanced(by: consumed)
            length = length - consumed
        }
    }
    
    func send(data: Data) throws {
        try data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) in
            try client.send(data: pointer, withLengthOf: data.count)
        }
    }
}
