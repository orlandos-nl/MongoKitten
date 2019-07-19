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
    let pool: _ConnectionPool
    let sessionManager: SessionManager
    let clusterTime: Document?
    let options: SessionOptions
    var sessionId: SessionIdentifier {
        return serverSession.sessionId
    }
    
    init(serverSession: ServerSession, pool: _ConnectionPool, sessionManager: SessionManager, options: SessionOptions) {
        self.serverSession = serverSession
        self.pool = pool
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
    func execute<C: MongoDBCommand>(command: C, transaction: TransactionQueryOptions? = nil) -> EventLoopFuture<C.Reply> {
        return pool.send(command: command, session: self, transaction: transaction).thenThrowing { reply in
            do {
                return try C.Reply(reply: reply)
            } catch {
                throw try C.ErrorReply(reply: reply)
            }
        }
    }
    
    func executeCancellable<C: MongoDBCommand>(command: C, transaction: TransactionQueryOptions? = nil) -> EventLoopFuture<Cancellable<C.Reply>> {
        return pool.sendCancellable(
            command: command,
            session: self,
            transaction: transaction
        ).map { cancellableResult in
            let mapped = cancellableResult.future.thenThrowing { reply -> C.Reply in
                do {
                    return try C.Reply(reply: reply)
                } catch {
                    throw try C.ErrorReply(reply: reply)
                }
            }
            
            return Cancellable(future: mapped, cancel: cancellableResult.cancel)
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
    private var transaction: Int = 1
    
    func nextTransactionNumber() -> Int {
        defer {
            // Overflow to negative will break new transactions
            // MongoDB has no solution other than using a different ServerSession
            transaction = transaction &+ 1
        }
        
        return transaction
    }
    
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
    
    func makeImplicitSession(for pool: _ConnectionPool) -> ClientSession {
        return ClientSession(
            serverSession: pool.sessionManager.implicitSession,
            pool: pool,
            sessionManager: pool.sessionManager,
            options: SessionOptions()
        )
    }
    
    init() {}
    
    func returnSession(_ session: ServerSession) {
        self.availableSessions.append(session)
    }
    
    func next(with options: SessionOptions, for pool: _ConnectionPool) -> ClientSession {
        let serverSession: ServerSession
        
        if availableSessions.count > 0 {
            serverSession = availableSessions.removeLast()
        } else {
            serverSession = .random
        }
        
        return ClientSession(serverSession: serverSession, pool: pool, sessionManager: self, options: options)
    }
}

extension Cluster {
    func startSession(with options: SessionOptions) -> ClientSession {
        return self.sessionManager.next(with: options, for: self)
    }
}

// TODO: Verify server feature version with https://github.com/mongodb/specifications/blob/master/source/retryable-writes/retryable-writes.rst#supported-server-versions
/// Supported single-statement write operations include insertOne(), updateOne(), replaceOne(), deleteOne(), findOneAndDelete(), findOneAndReplace(), and findOneAndUpdate().
//
// Supported multi-statement write operations include insertMany() and bulkWrite(). The ordered option may be true or false. In the case of bulkWrite(), UpdateMany or DeleteMany operations within the requests parameter may make some write commands ineligible for retryability. Drivers MUST evaluate eligibility for each write command sent as part of the bulkWrite()
// https://github.com/mongodb/specifications/blob/master/source/retryable-writes/retryable-writes.rst#how-will-users-know-which-operations-are-supported
// Write commands specifying an unacknowledged write concern (e.g. {w: 0})) do not support retryable behavior.
// https://github.com/mongodb/specifications/blob/master/source/retryable-writes/retryable-writes.rst#unsupported-write-operations
// TODO: Write commands
// In MongoDB 4.0 the only supported retryable write commands within a transaction are commitTransaction and abortTransaction. Therefore drivers MUST NOT retry write commands within transactions even when retryWrites has been enabled on the MongoClient. Drivers MUST retry the commitTransaction and abortTransaction commands even when retryWrites has been disabled on the MongoClient. commitTransaction and abortTransaction are retryable write commands and MUST be retried according to the Retryable Writes Specification.
public struct SessionOptions {
    public var casualConsistency: Bool?
    public var defaultTransactionOptions: TransactionOptions?
    
    public init() {}
}

extension Connection {

}
