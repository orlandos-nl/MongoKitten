import Tracing
import NIO
import MongoClient

extension MongoCollection {
    /// Creates a new index by this name. If the index already exists, a new one is _not_ created.
    /// - returns: A future indicating success or failure.
    /// 
    /// See also: [CreateIndexes Command](https://docs.mongodb.com/manual/reference/command/createIndexes/)
    public func createIndex(named name: String, keys: Document) async throws {
        return try await createIndexes([.init(named: name, keys: keys)])
    }
    
    /// Create 1 or more indexes on the collection.
    /// - Parameter indexes: A collection of indexes to be created.
    /// - Returns: A future indicating success or failure.
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
            baggage: baggage
        )
        
        try reply.assertOK()
    }
    
    /// Lists all indexes in this collection as a cursor.
    /// - returns: A cursor pointing towards all Index documents.
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
        if let baggage {
            listIndexesSpan = InstrumentationSystem.tracer.startAnySpan("ListIndexes<\(namespace)>", baggage: baggage)
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
            baggage: listIndexesSpan.baggage
        )
        
        return MongoCursor(
            reply: response.cursor,
            in: namespace,
            connection: connection,
            session: self.session ?? connection.implicitSession,
            transaction: nil,
            traceLabel: "ListIndexes<\(namespace)>",
            baggage: listIndexesSpan.baggage
        ).decode(MongoIndex.self)
    }
    
    /// Creates indexes based on the provided builder.
    /// - Parameter build: A builder that creates indexes
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
