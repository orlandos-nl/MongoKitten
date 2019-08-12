import BSON

public struct ListDatabases: Encodable {
    let listDatabases: Int32 = 1
    public var filter: Document?

    public init() {}
}

public struct ListDatabasesResponse: Decodable {
    public let databases: [DatabaseDescription]
//    let totalSize: Int
}

public struct DatabaseDescription: Codable {
    public let name: String
    public let sizeOnDisk: Int
    public let empty: Bool
}
