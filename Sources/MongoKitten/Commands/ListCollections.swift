import MongoClient

struct ListCollections: Encodable {
    let listCollections: Int32 = 1
    var filter: Document?

    init() {}
}

struct CollectionDescription: Codable {
    let name: String
}
