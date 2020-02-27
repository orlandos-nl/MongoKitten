import NIO
import MongoClient
import Foundation

/// A reference to a collection in a `Database`.
///
/// MongoDB stores documents in collections. Collections are analogous to tables in relational databases.
public final class MongoCollection {
    // MARK: Properties
    internal var transaction: MongoTransaction?
    public internal(set) var session: MongoClientSession?
    public var sessionId: SessionIdentifier? {
        return session?.sessionId
    }
    
    public var isInTransaction: Bool {
        return self.transaction != nil
    }

    /// The name of the collection
    public let name: String

    /// The database this collection resides in
    public let database: MongoDatabase
    
    public internal(set) var hoppedEventLoop: EventLoop?

    public var eventLoop: EventLoop {
        return pool.eventLoop
    }
    
    public func hopped(to eventloop: EventLoop) -> MongoCollection {
        let collection = MongoCollection(named: self.name, in: self.database)
        collection.hoppedEventLoop = eventloop
        return collection
    }
    
    internal func makeTransactionError<T>() -> EventLoopFuture<T> {
        return eventLoop.makeFailedFuture(
            MongoKittenError(.unsupportedFeatureByServer, reason: .transactionForUnsupportedQuery)
        )
    }

//    internal func makeTransactionQueryOptions() -> MongoTransactionOptions? {
//        guard let transaction = transaction else {
//            return nil
//        }
//
//        defer {
//            transaction.started = true
//            transaction.active = true
//        }
//
//        return TransactionQueryOptions(
//            id: transaction.id,
//            startTransaction: !transaction.started,
//            autocommit: transaction.autocommit ?? false
//        )
//    }

    internal var pool: MongoConnectionPool {
        return self.database.pool
    }
    
    public var namespace: MongoNamespace {
        return MongoNamespace(to: self.name, inDatabase: self.database.name)
    }

    /// Initializes this collection with by the database it's in and the collection name
    internal init(named name: String, in database: MongoDatabase) {
        self.name = name
        self.database = database
    }
    
    public func drop() -> EventLoopFuture<Void> {
        return pool.next(for: .writable).flatMap { connection in
            return connection.executeCodable(
                DropCollectionCommand(named: self.name),
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: connection.implicitSessionId
            )
        }.map { _ in }
    }
}
