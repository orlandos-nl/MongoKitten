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

public protocol ConnectionPool {
    func retain() -> Future<DatabaseConnection>
}

/// A connection to MongoDB
public final class DatabaseConnection: ConnectionPool {
    public func retain() -> Future<DatabaseConnection> {
        return Future(self)
    }
    
    var requestID: Int32 = 0
    
    var nextRequestId: Int32 {
        defer { requestID = requestID &+ 1 }
        return requestID
    }
    
    /// The responses being waited for
    var waitingForResponses = [Int32: Promise<ServerReply>]()
    
    fileprivate var doClose: (()->())?
    fileprivate var strongSocketReference: Any?
    
    let parser = ServerReplyParser()
    let serializer: PacketSerializer
    
    init<DuplexStream: Async.Stream & ClosableStream>(connection: DuplexStream) where DuplexStream.Input == ByteBuffer, DuplexStream.Output == ByteBuffer {
        self.strongSocketReference = connection
        self.serializer = PacketSerializer(connection: connection)
        
        connection.stream(to: parser).drain { reply in
            self.waitingForResponses[reply.responseTo]?.complete(reply)
            self.waitingForResponses[reply.responseTo] = nil
        }
        
        self.doClose = {
            connection.close()
        }
    }
    
    public static func connect(host: MongoHost, credentials: MongoCredentials? = nil, ssl: SSLSettings = false, worker: Worker) throws -> Future<DatabaseConnection> {
        if ssl.enabled {
            let tls = try TLSClient(worker: worker)
            tls.clientCertificatePath = ssl.clientCertificate
            
            let promise = Promise<DatabaseConnection>()
            
            tls.catch(promise.fail)
            
            try tls.connect(hostname: host.hostname, port: host.port).map {
                return DatabaseConnection(connection: tls)
            }.flatMap { connection in
                if let credentials = credentials {
                    return try connection.authenticate(with: credentials)
                } else {
                    return Future(connection)
                }
            }.do(promise.complete).catch(promise.fail)
            
            return promise.future
        } else {
            let socket = try Socket()
            let client = TCPClient(socket: socket, worker: worker)
            
            let promise = Promise<DatabaseConnection>()
            
            client.catch(promise.fail)
            
            try socket.connect(hostname: host.hostname, port: host.port)
            
            socket.writable(queue: worker.eventLoop.queue).map { () -> DatabaseConnection in
                client.start()
                
                return DatabaseConnection(connection: client)
            }.flatMap { connection in
                if let credentials = credentials {
                    return try connection.authenticate(with: credentials)
                } else {
                    return Future(connection)
                }
            }.do(promise.complete).catch(promise.fail)
            
            return promise.future
        }
    }
    
    /// Authenticates this connection to a database
    ///
    /// - parameter db: The database to authenticate to
    ///
    /// - throws: Authentication error
    func authenticate(with credentials: MongoCredentials) throws -> Future<DatabaseConnection> {
        
        return Future(())
        
        if let details = db.clientSettings.credentials {
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
        let promise = Promise<ServerReply>()
        
        self.waitingForResponses[message.requestID] = promise
        
        serializer.inputStream(message)
        
        return promise.future
    }
}
