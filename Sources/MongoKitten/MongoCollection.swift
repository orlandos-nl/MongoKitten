import Tracing
import NIO
import MongoClient
import Foundation

/// A reference to a collection in a `MongoDatabase`.
///
/// `MongoCollection` represents a MongoDB collection and provides methods for performing CRUD operations
/// (Create, Read, Update, Delete) on documents within the collection.
///
/// ## Basic Usage
/// ```swift
/// // Get a collection reference
/// let users = database["users"]
///
/// // Insert a document
/// try await users.insert(["username": "alice", "age": 25])
///
/// // Find documents
/// let youngUsers = users.find("age" < 30)
/// for try await user in youngUsers {
///     print(user)
/// }
///
/// // Update documents
/// try await users.updateMany(
///     where: "age" < 18,
///     setting: ["isMinor": true]
/// )
///
/// // Delete documents
/// try await users.deleteOne(where: "username" == "alice")
/// ```
///
/// ## Transactions
/// Collections support transactions when used within a transaction context:
/// ```swift
/// let transaction = try await db.startTransaction(autoCommitChanges: false)
/// let users = transaction["users"]
///
/// try await users.insertOne(["username": "bob"])
/// try await transaction.commit()
/// ```
///
/// ## Indexes
/// Collections support index creation for query optimization:
/// ```swift
/// try await users.buildIndexes {
///     UniqueIndex(named: "unique-username", field: "username")
///     TextIndex(named: "search-bio", field: "bio")
/// }
/// ```
///
/// ## Aggregation Pipeline
/// Collections support MongoDB's powerful aggregation framework:
/// ```swift
/// let pipeline = users.buildAggregate {
///     Match(where: "age" > 18)
///     Group(by: "$country", [
///         "averageAge": Average(of: "$age")
///     ])
/// }
///
/// for try await result in pipeline {
///     print(result)
/// }
/// ```
public final class MongoCollection: Sendable {
    // MARK: Properties
    internal let context: ServiceContext?
    internal let transaction: MongoTransaction?

    /// The session this collection is bound to
    ///
    /// Sessions are used for causal consistency and transactions.
    /// If `nil`, operations will use an implicit session.
    public let session: MongoClientSession?

    /// The session identifier for this collection's session
    ///
    /// This is used internally for creating database commands.
    /// If `nil`, the collection is not bound to a session.
    public var sessionId: SessionIdentifier? {
        return session?.sessionId
    }
    
    /// Whether this collection is part of a transaction
    ///
    /// If `true`, all operations on this collection will be part of the transaction
    /// and will either commit or rollback together.
    public var isInTransaction: Bool {
        return self.transaction != nil
    }

    /// The name of this collection
    ///
    /// This is the collection's identifier within its database.
    /// For example, in a URL like "mongodb://localhost/mydb.users",
    /// the collection name would be "users".
    public let name: String

    /// The database this collection belongs to
    ///
    /// Used to access database-level operations and settings.
    public let database: MongoDatabase
    
    internal var pool: MongoConnectionPool {
        return self.database.pool
    }
    
    /// The full namespace of this collection
    ///
    /// A namespace uniquely identifies a collection within MongoDB
    /// by combining the database name and collection name.
    /// For example: "mydb.users"
    public var namespace: MongoNamespace {
        return MongoNamespace(to: self.name, inDatabase: self.database.name)
    }

    /// Creates a new collection instance
    ///
    /// This is typically not called directly. Instead, use the subscript
    /// operator on `MongoDatabase`:
    /// ```swift
    /// let users = database["users"]
    /// ```
    internal init(
        named name: String,
        in database: MongoDatabase,
        context: ServiceContext?,
        transaction: MongoTransaction?,
        session: MongoClientSession?
    ) {
        self.name = name
        self.database = database
        self.context = context
        self.transaction = transaction
        self.session = session
    }
    
    /// Drops this collection and all its indexes
    ///
    /// This operation cannot be undone. Use with caution.
    ///
    /// Example:
    /// ```swift
    /// try await users.drop()
    /// ```
    ///
    /// - Throws: `MongoError` if the operation fails
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
