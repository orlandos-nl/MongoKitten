import BSON
import NIO
import Foundation

struct SessionIdentifier: Codable {
    var id: Binary
    
    init(allocator: ByteBufferAllocator) {
        let uuid = UUID().uuid
        
        var buffer = allocator.buffer(capacity: 16)
        buffer.write(integer: uuid.0)
        buffer.write(integer: uuid.1)
        buffer.write(integer: uuid.2)
        buffer.write(integer: uuid.3)
        buffer.write(integer: uuid.4)
        buffer.write(integer: uuid.5)
        buffer.write(integer: uuid.6)
        buffer.write(integer: uuid.7)
        buffer.write(integer: uuid.8)
        buffer.write(integer: uuid.9)
        buffer.write(integer: uuid.10)
        buffer.write(integer: uuid.11)
        buffer.write(integer: uuid.12)
        buffer.write(integer: uuid.13)
        buffer.write(integer: uuid.14)
        buffer.write(integer: uuid.15)
        
        self.id = Binary(subType: .uuid, buffer: buffer)
    }
}

public final class ClientSession {
    let serverSession: ServerSession
    // TODO: Sessions within a cluster rather than a single (TCP) connection
    let connection: Connection
    let sessionManager: SessionManager
    let clusterTime: Document?
    let options: SessionOptions
    var sessionId: SessionIdentifier {
        return serverSession.sessionId
    }
    
    init(serverSession: ServerSession, connection: Connection, sessionManager: SessionManager, options: SessionOptions) {
        self.serverSession = serverSession
        self.connection = connection
        self.sessionManager = sessionManager
        self.options = options
        self.clusterTime = nil
    }
    
    func advanceClusterTime(to time: Document) {
        // Increase if the new time is in the future
        // Ignore if the new time <= the current time
    }
    
    /// Executes the given MongoDB command, returning the result
    ///
    /// - parameter command: The `MongoDBCommand` to execute
    /// - returns: The reply to the command
    func execute<C: MongoDBCommand>(command: C) -> EventLoopFuture<C.Reply> {
        return connection._execute(command: command, session: self).thenThrowing { reply in
            do {
                return try C.Reply(reply: reply)
            } catch {
                throw try C.ErrorReply(reply: reply)
            }
        }
    }
    
    subscript(namespace: Namespace) -> Collection {
        return Database(named: namespace.databaseName, session: self)[namespace.collectionName]
    }
    
//    public func end() -> EventLoopFuture<Void> {
//        let command = EndSessionsCommand(
//            [sessionId],
//            inNamespace: connection["admin"]["$cmd"].namespace
//        )
//
    //        return command.execute(on: connection)
//    }

    deinit {
        sessionManager.returnSession(serverSession)
    }
}

internal final class ServerSession {
    let sessionId: SessionIdentifier
    let lastUse: Date
    
    init(for sessionId: SessionIdentifier) {
        self.sessionId = sessionId
        self.lastUse = Date()
    }
    
    fileprivate static let allocator = ByteBufferAllocator()
    static var random: ServerSession {
        return ServerSession(for: SessionIdentifier(allocator: allocator))
    }
}

final class SessionManager {
    var availableSessions = [ServerSession]()
    
    init() {}
    
    func returnSession(_ session: ServerSession) {
        self.availableSessions.append(session)
    }
    
    func next(withOptions options: SessionOptions, forConnection connection: Connection) -> ClientSession {
        let serverSession: ServerSession
        
        if availableSessions.count > 0 {
            serverSession = availableSessions.removeLast()
        } else {
            serverSession = .random
        }
        
        return ClientSession(serverSession: serverSession, connection: connection, sessionManager: self, options: options)
    }
}

extension Connection {
    public func startSession(withOptions options: SessionOptions) -> ClientSession {
        return sessionManager.next(withOptions: options, forConnection: self)
    }
}

extension Cluster {
    public func startSession(withOptions options: SessionOptions) -> EventLoopFuture<ClientSession> {
        return self.getConnection().map { connection in
            return connection.startSession(withOptions: options)
        }
    }
}

//final class Transaction {
//    let session: ClientSession
//
//    deinit {
//
//    }
//}
//
public struct SessionOptions {
    public init() {}
}

extension Connection {

}
