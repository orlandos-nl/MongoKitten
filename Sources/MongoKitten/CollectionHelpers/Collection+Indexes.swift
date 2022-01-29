import NIO
import MongoClient

extension MongoCollection {
    /// Creates a new index by this name. If the index already exists, a new one is _not_ created.
    /// - returns: A future indicating success or failure.
    public func createIndex(named name: String, keys: Document) async throws {
        return try await createIndexes([.init(named: name, keys: keys)])
    }
    
    /// Create 1 or more indexes on the collection.
    /// - Parameter indexes: A collection of indexes to be created.
    /// - Returns: A future indicating success or failure.
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
            sessionId: self.sessionId ?? connection.implicitSessionId
        )
        
        try reply.assertOK()
    }
    
    /// Lists all indexes in this collection as a cursor.
    /// - returns: A cursor pointing towards all Index documents.
    public func listIndexes() async throws -> MappedCursor<MongoCursor, MongoIndex> {
        struct Request: Codable, Sendable {
            let listIndexes: String
        }
        
        let request = Request(listIndexes: name)
        let db = self.database
        let namespace = MongoNamespace(to: "$cmd", inDatabase: db.name)
        
        let connection = try await db.pool.next(for: .basic)
        let response = try await connection.executeCodable(
            request,
            decodeAs: MongoCursorResponse.self,
            namespace: namespace,
            sessionId: nil
        )
        
        return MongoCursor(
            reply: response.cursor,
            in: namespace,
            connection: connection,
            session: self.session ?? connection.implicitSession,
            transaction: nil
        ).decode(MongoIndex.self)
    }
}

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
    public let name: String
    public let key: Document
    public let namespace: MongoNamespace?
    public let unique: Bool?
    public let sparse: Bool?
    public let expireAfterSeconds: Int32?
    public let sphere2dIndexVersion: Int?
}
