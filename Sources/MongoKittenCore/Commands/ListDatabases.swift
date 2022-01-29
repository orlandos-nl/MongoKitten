import BSON

public struct ListDatabases: Encodable, Sendable {
    let listDatabases: Int32 = 1
    public var filter: Document?

    public init() {}
}

public struct ListDatabasesResponse: Decodable, Sendable {
    public let databases: [DatabaseDescription]
//    let totalSize: Int
}

public struct DatabaseDescription: Codable, Sendable {
    public let name: String
    public let sizeOnDisk: Int
    public let empty: Bool
}
