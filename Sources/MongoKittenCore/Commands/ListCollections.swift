import BSON
import MongoClient

public struct ListCollections: Encodable, Sendable {
    let listCollections: Int32 = 1
    public var filter: Document?

    public init() {}
}

public struct CollectionDescription: Codable, Sendable {
    public let name: String
}
