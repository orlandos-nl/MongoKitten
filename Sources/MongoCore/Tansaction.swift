/// A MongoDB transaction that can be used to execute multiple operations in a single transaction.
public final actor MongoTransaction: Sendable {
    /// The transaction number
    public nonisolated let number: Int

    private var _startTransaction = true

    /// Whether the transaction should be automatically committed
    public nonisolated let autocommit: Bool
    
    init(number: Int, autocommit: Bool) {
        self.number = number
        self.autocommit = autocommit
    }
    
    /// Whether the transaction should be started
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
