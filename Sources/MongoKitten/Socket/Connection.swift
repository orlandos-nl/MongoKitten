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
    fileprivate var client: MongoTCP!
    
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
    
    /// Handles mutations the response buffer
    internal static let mutationsQueue = DispatchQueue(label: "org.mongokitten.server.responseQueue", qos: DispatchQoS.userInteractive)
    
    /// The responses being waited for
    var waitingForResponses = [Int32: ManualPromise<ServerReply>]()
    
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

        self.client = try MongoSocket(address: host.hostname, port: host.port, options: options, onRead: self.onRead, onError: { _ in
            self.close()
        })
    }
    
    /// Authenticates this connection to a database
    ///
    /// - parameter db: The database to authenticate to
    ///
    /// - throws: Authentication error
    func authenticate(to db: Database) throws {
        if let details = db.server.clientSettings.credentials {
            do {
                let db = db.server[details.database ?? db.name]
                
                switch details.authenticationMechanism {
                case .SCRAM_SHA_1:
                    try db.authenticate(SASL: details, usingConnection: self)
                case .MONGODB_CR:
                    try db.authenticate(mongoCR: details, usingConnection: self)
                case .MONGODB_X509:
                    try db.server.authenticateX509(subject: details.username, usingConnection: self)
                default:
                    throw MongoError.unsupportedFeature("authentication Method \"\(details.authenticationMechanism.rawValue)\"")
                }
                
                self.authenticatedDBs.append(db.name)
            } catch { }
        }
    }
    
    /// Closes this connection
    func close() {
        _ = try? client.close()
        onClose()
        
        Connection.mutationsQueue.sync {
            for (_, callback) in self.waitingForResponses {
                _ = try? callback.fail(MongoError.notConnected)
            }
            
            self.waitingForResponses = [:]
        }
    }
    
    private func onRead(at pointer: UnsafeMutablePointer<UInt8>, withLengthOf length: Int) {
        let b = UnsafeBufferPointer<Byte>(start: pointer, count: length)
        buffer.data += [UInt8](b)
        
        _ = try? parseBuffer()
    }
    
    func send(data: [UInt8]) throws {
        try client.send(data: data, withLengthOf: data.count)
    }
    
    private func parseBuffer() throws {
        while buffer.data.count >= 36 {
            let length = Int(buffer.data[0...3].makeInt32())
            
            guard length <= buffer.data.count else {
                // Ignore: Wait for more data
                return
            }
            
            let responseData = buffer.data[0..<length]*
            let responseId = buffer.data[8...11].makeInt32()
            let reply = try Message.makeReply(from: responseData)
            
            defer {
                Connection.mutationsQueue.sync {
                    waitingForResponses[responseId] = nil
                }
            }
            
            try Connection.mutationsQueue.sync {
                if let promise = waitingForResponses[responseId] {
                    _ = try promise.complete(reply)
                }
                
                buffer.data.removeSubrange(0..<length)
            }
        }
    }
}
