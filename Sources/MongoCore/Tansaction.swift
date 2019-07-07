public struct MongoTransaction {
    public let id: Int
    public let startTransaction: Bool
    public let autocommit: Bool
}

public struct MongoTransactionOptions {
    // TODO: Read/Write concern and readPreference

    public init() {}
}
