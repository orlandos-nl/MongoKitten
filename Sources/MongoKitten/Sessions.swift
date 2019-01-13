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

final class ClientSession {
    let serverSession: ServerSession
    let cluster: Cluster
    let sessionManager: SessionManager
    let clusterTime: Document?
    let options: SessionOptions
    var sessionId: SessionIdentifier {
        return serverSession.sessionId
    }
    
    init(serverSession: ServerSession, cluster: Cluster, sessionManager: SessionManager, options: SessionOptions) {
        self.serverSession = serverSession
        self.cluster = cluster
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
        return cluster.send(command: command, session: self).thenThrowing { reply in
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
    private let implicitSession = ServerSession.random
    
    func makeImplicitSession(for cluster: Cluster) -> ClientSession {
        return ClientSession(
            serverSession: cluster.sessionManager.implicitSession,
            cluster: cluster,
            sessionManager: cluster.sessionManager,
            options: SessionOptions()
        )
    }
    
    init() {}
    
    func returnSession(_ session: ServerSession) {
        self.availableSessions.append(session)
    }
    
    func next(with options: SessionOptions, for cluster: Cluster) -> ClientSession {
        let serverSession: ServerSession
        
        if availableSessions.count > 0 {
            serverSession = availableSessions.removeLast()
        } else {
            serverSession = .random
        }
        
        return ClientSession(serverSession: serverSession, cluster: cluster, sessionManager: self, options: options)
    }
}

extension Cluster {
    func startSession(with options: SessionOptions) -> ClientSession {
        return self.sessionManager.next(with: options, for: self)
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
