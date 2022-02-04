public final actor MongoTransaction: Sendable {
    public nonisolated let number: Int
    private var _startTransaction = true
    public nonisolated let autocommit: Bool
    
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

public struct MongoTransactionOptions: Sendable {
    // TODO: Read/Write concern and readPreference

    public init() {}
}
