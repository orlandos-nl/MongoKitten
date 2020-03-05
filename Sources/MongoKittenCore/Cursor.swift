import MongoClient

public struct CursorSettings: Encodable {
    public var batchSize: Int?
    
    public init() {}
}

public struct CursorReply: Codable {
    public let cursor: MongoCursorResponse.Cursor
    private let ok: Int
}
