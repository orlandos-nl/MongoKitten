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
import AppleTLS

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
    
    fileprivate var socket: Socket
    
    let parser = ServerReplyParser()
    let serializer: PacketSerializer
    
    init<T>(source: SocketSource<T>, sink: SocketSink<T>) {
        self.socket = sink.socket
        self.serializer = PacketSerializer()
        
        serializer.output(to: sink)
        
        source.stream(to: parser).drain { upstream in
            upstream.request()
        }.output { reply in
            self.waitingForResponses[reply.responseTo]?.complete(reply)
            self.waitingForResponses[reply.responseTo] = nil
            self.parser.request()
        }.catch { error in
            for waiter in self.waitingForResponses.values {
                waiter.fail(error)
            }
            
            self.waitingForResponses = [:]
            
            self.socket.close()
        }.finally {
            self.socket.close()
        }
    }
    
    public subscript(database: String) -> Database {
        return Database(named: database, atServer: Server(connection: self))
    }
    
    public static func connect(host: MongoHost, credentials: MongoCredentials? = nil, ssl: SSLSettings = false, worker: Worker) throws -> Future<DatabaseConnection> {
        let socket = try TCPSocket()
        let client = try TCPClient(socket: socket)
        
        if ssl.enabled {
            let tls = try AppleTLSClient(tcp: client, using: TLSClientSettings(peerDomainName: host.hostname))
            try tls.connect(hostname: host.hostname, port: host.port)
            
            let sink = tls.socket.sink(on: worker)
            let source = tls.socket.source(on: worker)
            
            let connection = DatabaseConnection(source: source, sink: sink)
            
            if let credentials = credentials {
                return try connection.authenticate(with: credentials).transform(to: connection)
            } else {
                return Future(connection)
            }
        } else {
            try client.connect(hostname: host.hostname, port: host.port)
            
            let sink = socket.sink(on: worker)
            let source = socket.source(on: worker)
            
            let connection = DatabaseConnection(source: source, sink: sink)
            
            if let credentials = credentials {
                return try connection.authenticate(with: credentials).transform(to: connection)
            } else {
                return Future(connection)
            }
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
        self.socket.close()
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
        
        serializer.next(message)
        
        return promise.future
    }
}
