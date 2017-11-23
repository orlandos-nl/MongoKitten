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
    
    let scram = SCRAMContext()
    
    fileprivate var requestID: Int32 = 0
    
    var nextRequestId: Int32 {
        defer { requestID = requestID &+ 1 }
        return requestID
    }
    
    /// The responses being waited for
    var waitingForResponses = [Int32: Promise<ServerReply>]()
    
    var wireProtocol: Int = 0
    
    fileprivate var doClose: (()->())?
    fileprivate var strongSocketReference: Any?
    
    let parser = ServerReplyParser()
    let serializer: PacketSerializer
    
    init<DuplexStream: Async.Stream>(connection: DuplexStream) where DuplexStream.Input == ByteBuffer, DuplexStream.Output == ByteBuffer {
        self.strongSocketReference = connection
        self.serializer = PacketSerializer()
        serializer.drain(onInput: connection.onInput).catch(onError: connection.onError)
        
        connection.stream(to: parser).drain { reply in
            self.waitingForResponses[reply.responseTo]?.complete(reply)
            self.waitingForResponses[reply.responseTo] = nil
        }.catch { error in
            for waiter in self.waitingForResponses.values {
                waiter.fail(error)
            }
            
            self.waitingForResponses = [:]
            
            connection.close()
        }
        
        self.doClose = {
            connection.close()
        }
    }
    
    public static func connect(host: MongoHost, credentials: MongoCredentials? = nil, ssl: SSLSettings = false, worker: Worker) throws -> Future<DatabaseConnection> {
        if ssl.enabled {
            let tls = try TLSClient(on: worker)
            tls.clientCertificatePath = ssl.clientCertificate
            
            let promise = Promise<DatabaseConnection>()
            
            try tls.connect(hostname: host.hostname, port: host.port).map {
                return DatabaseConnection(connection: tls)
            }.flatMap { connection in
                if let credentials = credentials {
                    return try connection.authenticate(with: credentials).map { _ in
                        return connection
                    }
                } else {
                    return Future(connection)
                }
            }.do(promise.complete).catch(promise.fail)
            
            return promise.future
        } else {
            let socket = try TCPSocket()
            let client = TCPClient(socket: socket, worker: worker)
            
            let promise = Promise<DatabaseConnection>()
            
            try socket.connect(hostname: host.hostname, port: host.port)
            
            socket.writable(queue: worker.eventLoop.queue).map { () -> DatabaseConnection in
                client.start()
                
                return DatabaseConnection(connection: client)
            }.flatMap { connection in
                if let credentials = credentials {
                    return try connection.authenticate(with: credentials).map {
                        return connection
                    }
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
    func authenticate(with credentials: MongoCredentials) throws -> Future<Void> {
        switch credentials.authenticationMechanism {
        case .SCRAM_SHA_1:
            return try self.authenticateSASL(credentials)
        case .MONGODB_CR:
            return try self.authenticateCR(credentials)
        case .MONGODB_X509:
            return try self.authenticateX509(credentials: credentials)
        default:
            return Future(error: MongoError.unsupportedFeature("authentication Method \"\(credentials.authenticationMechanism.rawValue)\""))
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
    
    func send(message: Message) -> Future<ServerReply> {
        let promise = Promise<ServerReply>()
        
        self.waitingForResponses[message.requestID] = promise
        
        serializer.onInput(message)
        
        return promise.future
    }
}
