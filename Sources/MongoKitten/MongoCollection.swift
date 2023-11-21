import Tracing
import NIO
import MongoClient
import Foundation

/// A reference to a collection in a `MongoDatabase`.
///
/// MongoDB stores documents in collections. Collections are analogous to tables in relational databases.
public final class MongoCollection {
    // MARK: Properties
    internal var context: ServiceContext?
    internal var transaction: MongoTransaction?

    /// The session this collection is bound to. This is used for creating database commands.
    public internal(set) var session: MongoClientSession?

    /// The `SessionIdentifier` of the session this collection is bound to.
    /// If `nil`, this collection is not bound to a session.
    /// This is used for creating database commands.
    public var sessionId: SessionIdentifier? {
        return session?.sessionId
    }
    
    /// If `true`, **all** commands that are executed using this collection instance will be ran as part of a transaction.
    public var isInTransaction: Bool {
        return self.transaction != nil
    }

    /// The name of the collection
    public let name: String

    /// The database this collection resides in
    public let database: MongoDatabase
    
    internal var pool: MongoConnectionPool {
        return self.database.pool
    }
    
    /// The namespace of this collection, which is the database name and the collection name combined
    /// This is used for creating database commands
    public var namespace: MongoNamespace {
        return MongoNamespace(to: self.name, inDatabase: self.database.name)
    }

    /// Initializes this collection with by the database it's in and the collection name
    internal init(named name: String, in database: MongoDatabase, context: ServiceContext?) {
        self.name = name
        self.database = database
        self.context = context
    }
    
    /// Drops this collection from the database it's in and removes all documents from it.
    public func drop() async throws {
        let connection = try await pool.next(for: .writable)
        let reply = try await connection.executeEncodable(
            DropCollectionCommand(named: self.name),
            namespace: self.database.commandNamespace,
            in: self.transaction,
            sessionId: connection.implicitSessionId,
            logMetadata: database.logMetadata
        )
        
        guard try reply.isOK() else {
            throw MongoError(.queryFailure, reason: nil)
        }
    }
}
