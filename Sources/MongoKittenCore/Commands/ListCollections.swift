import BSON
import MongoClient

public struct ListCollections: Encodable {
    let listCollections: Int32 = 1
    public var filter: Document?

    public init() {}
}

public struct CollectionDescription: Codable {
    public let name: String
}
