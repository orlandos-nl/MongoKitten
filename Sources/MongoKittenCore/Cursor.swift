import MongoClient

public struct CursorSettings: Encodable, Sendable {
    public var batchSize: Int?
    
    public init() {}
}

public struct CursorReply: Codable, Sendable {
    public let cursor: MongoCursorResponse.Cursor
    private let ok: Int
}
