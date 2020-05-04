import NIO
import MongoClient

extension MongoCollection {
    /// Creates a new index by this name. If the index already exists, a new one is _not_ created.
    /// - returns: A future indicating success or failure.
    public func createIndex(named name: String, keys: Document) -> EventLoopFuture<Void> {
        guard transaction == nil else {
            return makeTransactionError()
        }
        
        return self.pool.next(for: .writable).flatMap { connection in
            return connection.executeCodable(
                CreateIndexes(
                    collection: self.name,
                    indexes: [CreateIndexes.Index(named: name, keys: keys)]
                ),
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: self.sessionId ?? connection.implicitSessionId
            )
        }.flatMapThrowing { reply in
            return try reply.assertOK()
        }._mongoHop(to: hoppedEventLoop)
    }
    
    /// Lists all indexes in this collection as a cursor.
    /// - returns: A cursor pointing towards all Index documents.
    public func listIndexes() -> EventLoopFuture<MappedCursor<MongoCursor, MongoIndex>> {
        struct Request: Codable {
            let listIndexes: String
        }
        
        let request = Request(listIndexes: name)
        let db = self.database
        let namespace = MongoNamespace(to: "$cmd", inDatabase: db.name)
        
        return db.pool.next(for: .init(writable: false)).flatMap { connection in
            return connection.executeCodable(
                request,
                namespace: namespace,
                sessionId: nil
            ).decodeReply(MongoCursorResponse.self).map { response in
                return MongoCursor(
                    reply: response.cursor,
                    in: namespace,
                    connection: connection,
                    session: connection.implicitSession,
                    transaction: nil
                ).decode(MongoIndex.self)
            }
        }
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
    public let namespace: MongoNamespace
    public let unique: Bool?
    public let sparse: Bool?
    public let expireAfterSeconds: Int32?
    public let sphere2dIndexVersion: Int?
}
