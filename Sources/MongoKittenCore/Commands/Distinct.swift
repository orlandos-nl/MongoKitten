import BSON
import MongoCore

public struct DistinctCommand: Codable, Sendable {
    private let distinct: String
    public var key: String
    public var query: Document?
    public var readConcern: ReadConcern?
    
    public init(onKey key: String, where query: Document? = nil, inCollection collection: String) {
        self.distinct = collection
        self.query = query
        self.key = key
    }
}

public struct DistinctReply: Decodable, Sendable {
    public let ok: Int
    private let values: Document
    public var distinctValues: [Primitive] {
        return values.values
    }
}
