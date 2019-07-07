import MongoClient

internal final class Transaction {
    let options: MongoTransactionOptions
    var active = false
    var started = false
    var autocommit: Bool?
    let id: Int

    init(options: MongoTransactionOptions, transactionId: Int) {
        self.options = options
        self.id = transactionId
    }
}
