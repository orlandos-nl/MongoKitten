public final class MongoTransaction {
    public let number: Int
    private var _startTransaction = true
    public let autocommit: Bool
    
    init(number: Int, autocommit: Bool) {
        self.number = number
        self.autocommit = autocommit
    }
    
    public func startTransaction() -> Bool {
        let startTransaction = self._startTransaction
        self._startTransaction = false
        return startTransaction
    }
}

public struct MongoTransactionOptions {
    // TODO: Read/Write concern and readPreference

    public init() {}
}
