struct ListDatabases: Encodable {
    let listDatabases: Int32 = 1
    var filter: Document?

    init() {}
}

struct ListDatabasesResponse: Decodable {
    let databases: [DatabaseDescription]
//    let totalSize: Int
}

struct DatabaseDescription: Codable {
    let name: String
    let sizeOnDisk: Int
    let empty: Bool
}
