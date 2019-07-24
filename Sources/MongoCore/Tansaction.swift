public final class MongoTransaction {
    public let id: Int
    public internal(set) var startTransaction = true
    public let autocommit: Bool
    
    init(id: Int, autocommit: Bool) {
        self.id = id
        self.autocommit = autocommit
    }
}

public struct MongoTransactionOptions {
    // TODO: Read/Write concern and readPreference

    public init() {}
}
