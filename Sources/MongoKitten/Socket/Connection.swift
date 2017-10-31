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
import Bits
import TLS
import Foundation
import Dispatch
import TCP

/// A connection to MongoDB
public final class DatabaseConnection {
    /// The host that's connected to
    let host: MongoHost
    
    /// The currently constructing reply
    let parser = ServerReplyParser()
    
    var requestID: Int32 = 0
    
    var nextRequestId: Int32 {
        defer { requestID = requestID &+ 1 }
        return requestID
    }
    
    /// The responses being waited for
    var waitingForResponses = [Int32: Promise<ServerReply>]()
    
    fileprivate var doClose: (()->())?
    fileprivate var strongSocketReference: TCPClient?
    
    public static func connect(to database: Database, settings: ClientSettings, worker: Worker) throws -> Future<DatabaseConnection> {
        var hosts = settings.hosts.makeIterator()
        
        func attemptConnection(host: MongoHost) throws -> Future<DatabaseConnection> {
            let connection = DatabaseConnection(host: host, settings: settings, queue: worker.queue)
            
            let promise = Promise<DatabaseConnection>()
            
            func retryOnFailure(future: Future<Void>) {
                future.then {
                    promise.complete(connection)
                }.catch { error in
                    guard let host = hosts.next() else {
                        promise.fail(error)
                        return
                    }
                    
                    do {
                        promise.flatten(try attemptConnection(host: host))
                    } catch {
                        promise.fail(error)
                    }
                }
            }
            
            if settings.ssl.enabled {
                let tls = try TLSClient(worker: worker)
                tls.clientCertificatePath = settings.ssl.clientCertificate
                
                let result = try tls.connect(hostname: host.hostname, port: host.port).flatten {
                    try connection.authenticate(to: database)
                }.map {
                    connection.doClose = {
                        tls.close()
                    }
                    
                    connection.strongSocketReference = tls
                }
                
                retryOnFailure(future: result)
            } else {
                let socket = try Socket()
                let client = TCPClient(socket: socket, worker: worker)
                
                try socket.connect(hostname: host.hostname, port: host.port)
                    
                let result = socket.writable(queue: worker.queue).flatten {
                    try connection.authenticate(to: database)
                }.map {
                    connection.doClose = {
                        socket.close()
                    }
                    
                    connection.strongSocketReference = socket
                }.map {
                    client.start()
                }
                
                retryOnFailure(future: result)
            }
        }
        
        guard let host = hosts.next() else {
            throw MongoError.internalInconsistency
        }
        
        return try attemptConnection(host: host)
    }
    
    /// Simply creates a new connection from existing data
    init(host: MongoHost, settings: ClientSettings, queue: DispatchQueue) {
        self.host = host
    }
    
    /// Authenticates this connection to a database
    ///
    /// - parameter db: The database to authenticate to
    ///
    /// - throws: Authentication error
    func authenticate(to db: Database) throws -> Future<Void> {
        if let details = db.server.clientSettings.credentials {
            fatalError()
//            let db = db.server[details.database ?? db.name]
//
//            switch details.authenticationMechanism {
//            case .SCRAM_SHA_1:
//                return try self.authenticate(SASL: details, to: db)
//            case .MONGODB_CR:
//                return try self.authenticate(mongoCR: details, to: db)
//            case .MONGODB_X509:
//                return try self.authenticateX509(subject: details.username, to: db)
//            default:
//                throw MongoError.unsupportedFeature("authentication Method \"\(details.authenticationMechanism.rawValue)\"")
//            }
        }
    }
    
    /// Closes this connection
    public func close() {
        self.doClose?()
        self.closeResponses()
    }
    
    func closeResponses() {
        for (_, callback) in self.waitingForResponses {
            callback.fail(MongoError.notConnected)
        }
        
        self.waitingForResponses = [:]
    }
    
    func send(message: Message) throws -> Future<ServerReply> {
        let messageData = try message.generateData()
        let promise = Promise<ServerReply>()
        
        messageData.withUnsafeBytes { (pointer: BytesPointer) in
            strongSocketReference.inputStream(ByteBuffer(start: pointer, count: messageData.count))
        }
        
        return promise.future
    }
    
    private func onRead(at pointer: UnsafeMutablePointer<UInt8>, withLengthOf length: Int) {
        func checkComplete() {
            if nextReply.isComplete {
                defer { nextReply = ServerReplyPlaceholder() }
                
                guard let reply = nextReply.construct() else {
                    return
                }
                
                if let promise = waitingForResponses[reply.responseTo] {
                    try promise.complete { reply }
                    waitingForResponses[reply.responseTo] = nil
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
}
