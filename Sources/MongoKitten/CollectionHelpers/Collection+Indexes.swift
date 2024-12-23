import Tracing
import NIO
import MongoClient

/// Extension providing index management functionality for `MongoCollection`
///
/// MongoDB indexes support the efficient execution of queries. Without indexes,
/// MongoDB must perform a collection scan to select documents matching a query.
/// If an appropriate index exists, MongoDB can use the index to limit the number
/// of documents it must inspect.
///
/// ## Index Types
/// MongoKitten supports several types of indexes:
/// - `SortedIndex`: Basic index for fast queries and sorting
/// - `UniqueIndex`: Ensures field values are unique across documents
/// - `TTLIndex`: Automatically removes documents after a specified time
/// - `TextScoreIndex`: Enables full-text search capabilities
///
/// ## Basic Usage
/// ```swift
/// // Create a single field index
/// try await users.buildIndexes {
///     SortedIndex(named: "age-index", field: "age")
/// }
///
/// // Create a unique index
/// try await users.buildIndexes {
///     UniqueIndex(named: "unique-email", field: "email")
/// }
///
/// // Create a TTL index that expires documents after 24 hours
/// try await users.buildIndexes {
///     TTLIndex(
///         named: "expire-temp",
///         field: "createdAt",
///         expireAfterSeconds: 24 * 60 * 60
///     )
/// }
///
/// // Create multiple indexes at once
/// try await users.buildIndexes {
///     SortedIndex(named: "age-index", field: "age")
///     UniqueIndex(named: "unique-email", field: "email")
///     TextScoreIndex(named: "search-bio", field: "bio")
/// }
/// ```
///
/// ## Compound Indexes
/// You can create indexes on multiple fields:
/// ```swift
/// try await users.buildIndexes {
///     SortedIndex(
///         by: ["country": .ascending, "age": .descending],
///         named: "country-age-index"
///     )
/// }
/// ```
extension MongoCollection {
    /// Creates a new index on this collection
    ///
    /// If an index with the same name already exists, a new one is not created.
    ///
    /// - Parameters:
    ///   - name: A unique name for the index
    ///   - keys: The fields and their sort order to index
    /// - Throws: `MongoError` if the index creation fails
    ///
    /// Example:
    /// ```swift
    /// try await users.createIndex(
    ///     named: "age-index",
    ///     keys: ["age": 1]  // 1 for ascending, -1 for descending
    /// )
    /// ```
    /// 
    /// See also: [CreateIndexes Command](https://docs.mongodb.com/manual/reference/command/createIndexes/)
    public func createIndex(named name: String, keys: Document) async throws {
        return try await createIndexes([.init(named: name, keys: keys)])
    }
    
    /// Creates multiple indexes on this collection
    ///
    /// This is more efficient than creating indexes one at a time.
    /// If any of the indexes already exist, they are skipped.
    ///
    /// - Parameter indexes: Array of index specifications to create
    /// - Throws: `MongoError` if the index creation fails
    /// - Note: Cannot be used within a transaction
    ///
    /// Example:
    /// ```swift
    /// var emailIndex = CreateIndexes.Index(named: "email", keys: ["email": 1])
    /// emailIndex.unique = true
    /// 
    /// try await users.createIndexes([
    ///     CreateIndexes.Index(named: "age", keys: ["age": 1]),
    ///     emailIndex
    /// ])
    /// ```
    /// 
    /// See also: [CreateIndexes Command](https://docs.mongodb.com/manual/reference/command/createIndexes/)
    public func createIndexes(_ indexes: [CreateIndexes.Index]) async throws {
        guard transaction == nil else {
            throw MongoKittenError(.unsupportedFeatureByServer, reason: .transactionForUnsupportedQuery)
        }
        
        let connection = try await database.pool.next(for: .writable)
        let reply = try await connection.executeEncodable(
            CreateIndexes(
                collection: self.name,
                indexes: indexes
            ),
            namespace: self.database.commandNamespace,
            in: self.transaction,
            sessionId: self.sessionId ?? connection.implicitSessionId,
            logMetadata: database.logMetadata,
            traceLabel: "CreateIndexes<\(namespace)>",
            serviceContext: context
        )
        
        try reply.assertOK()
    }
    
    /// Lists all indexes in this collection
    ///
    /// Returns information about each index including:
    /// - Name
    /// - Key fields and their sort order
    /// - Whether the index is unique
    /// - Whether the index is sparse
    /// - TTL settings (if applicable)
    ///
    /// - Returns: A cursor of `MongoIndex` objects describing each index
    /// - Throws: `MongoError` if the operation fails
    /// 
    /// Example:
    /// ```swift
    /// let indexes = try await users.listIndexes().drain()
    /// for index in indexes {
    ///     print("Index: \(index.name)")
    ///     print("Keys: \(index.key)")
    ///     if let ttl = index.expireAfterSeconds {
    ///         print("TTL: \(ttl) seconds")
    ///     }
    /// }
    /// ```
    /// 
    /// See also: [ListIndexes Command](https://docs.mongodb.com/manual/reference/command/listIndexes/)
    public func listIndexes() async throws -> MappedCursor<MongoCursor, MongoIndex> {
        struct Request: Codable, Sendable {
            let listIndexes: String
        }
        
        let request = Request(listIndexes: name)
        let db = self.database
        let namespace = MongoNamespace(to: "$cmd", inDatabase: db.name)
        
        let connection = try await db.pool.next(for: .basic)
        let listIndexesSpan: any Span
        if let context {
            listIndexesSpan = InstrumentationSystem.tracer.startAnySpan("ListIndexes<\(namespace)>", context: context)
        } else {
            listIndexesSpan = InstrumentationSystem.tracer.startAnySpan("ListIndexes<\(namespace)>")
        }
        let response = try await connection.executeCodable(
            request,
            decodeAs: MongoCursorResponse.self,
            namespace: namespace,
            sessionId: nil,
            logMetadata: database.logMetadata,
            traceLabel: "ListIndexes<\(namespace)>",
            serviceContext: listIndexesSpan.context
        )
        
        return MongoCursor(
            reply: response.cursor,
            in: namespace,
            connection: connection,
            session: self.session ?? connection.implicitSession,
            transaction: nil,
            traceLabel: "ListIndexes<\(namespace)>",
            context: listIndexesSpan.context
        ).decode(MongoIndex.self)
    }
    
    /// Creates indexes using a builder pattern
    ///
    /// This is the recommended way to create indexes as it provides
    /// type-safe construction of various index types.
    ///
    /// - Parameter build: A closure that builds index specifications
    /// - Throws: `MongoError` if index creation fails
    /// - Note: Cannot be used within a transaction
    ///
    /// Example:
    /// ```swift
    /// try await users.buildIndexes {
    ///     // Basic index for fast queries and sorting
    ///     SortedIndex(named: "age-index", field: "age")
    ///
    ///     // Unique index to enforce uniqueness
    ///     UniqueIndex(named: "email-index", field: "email")
    ///
    ///     // TTL index for automatic document expiration
    ///     TTLIndex(
    ///         named: "temp-index",
    ///         field: "createdAt",
    ///         expireAfterSeconds: 24 * 60 * 60
    ///     )
    ///
    ///     // Text index for full-text search
    ///     TextScoreIndex(named: "search-index", field: "description")
    /// }
    /// ```
    /// 
    /// See also: [CreateIndexes Command](https://docs.mongodb.com/manual/reference/command/createIndexes/)
    public func buildIndexes(@MongoIndexBuilder build: () -> _MongoIndexes) async throws {
        return try await createIndexes(build().indexes)
    }
}

/// A single index to be created
public struct MongoIndex: Decodable {
    private enum CodingKeys: String, CodingKey {
        case version = "v"
        case namespace = "ns"
        case name
        case key
        case sparse
        case unique
        case sphere2dIndexVersion = "2dsphereIndexVersion"
        case expireAfterSeconds
    }
    
    public let version: Int

    /// The name of this index
    public let name: String

    /// The specification of this index
    public let key: Document

    /// The namespace of the collection this index is on
    public let namespace: MongoNamespace?

    /// Whether the keys in this index are unique
    public let unique: Bool?

    /// Whether the keys in this index are sparse
    public let sparse: Bool?

    /// The time in seconds after which documents expire, if this is a TTL index
    public let expireAfterSeconds: Int32?

    /// The version of the 2D sphere index, if this is a 2D sphere index
    public let sphere2dIndexVersion: Int?
}
