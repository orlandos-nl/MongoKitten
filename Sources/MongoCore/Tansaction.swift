public struct MongoTransaction {
    public let number: Int
    public internal(set) var startTransaction = true
    public let autocommit: Bool
    
    init(number: Int, autocommit: Bool) {
        self.number = number
        self.autocommit = autocommit
    }
}

public struct MongoTransactionOptions {
    // TODO: Read/Write concern and readPreference

    public init() {}
}
