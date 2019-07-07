import MongoCore

public struct DropDatabaseCommand: Encodable {
    private let dropDatabase: Int = 1

    public init() {}
}

public struct DropCollectionCommand: Encodable {
    private enum CodingKeys: String, CodingKey {
        case collection = "drop"
        case writeConcern
    }

    public let collection: String
    public var writeConcern: WriteConcern?

    public init(named name: String) {
        self.collection = name
    }
}
