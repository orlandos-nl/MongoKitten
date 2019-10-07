import MongoClient

public struct CursorSettings: Encodable {
    public var batchSize: Int?
    
    public init() {}
}

public struct CursorReply: Codable {
    public let cursor: MongoCursorResponse.Cursor
    private let ok: Int

    public func makeCursor(collection: MongoNamespace, connection: MongoConnection, transaction: MongoTransaction?) throws -> MongoCursor {
        return MongoCursor(
            reply: cursor,
            in: collection,
            connection: connection,
            session: connection.implicitSession,
            transaction: transaction
        )
    }
}
