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
    
    public func drop() async throws {
        let connection = try await pool.next(for: .writable)
        let reply = try await connection.executeEncodable(
            DropCollectionCommand(named: self.name),
            namespace: self.database.commandNamespace,
            in: self.transaction,
            sessionId: connection.implicitSessionId
        )
        
        guard try reply.isOK() else {
            throw MongoError(.queryFailure, reason: nil)
        }
    }
}
