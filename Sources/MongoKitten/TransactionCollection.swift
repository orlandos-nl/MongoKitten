import NIO

public final class TransactionDatabase: Database {
    internal init(named name: String, session: ClientSession, transaction: Transaction) {
        super.init(named: name, session: session)
        
        self.transaction = transaction
    }
    
    public override subscript(collection: String) -> TransactionCollection {
        let collection = TransactionCollection(named: collection, in: self)
        collection.transaction = self.transaction
        return collection
    }
}

// TODO: Transitions: https://github.com/mongodb/specifications/raw/master/source/transactions/client-session-transaction-states.png
public final class TransactionCollection: Collection {
    public func commit() -> EventLoopFuture<Void> {
        // Crash if the transaction is `nil`, this is a bad violation of the API
        guard let transactionQueryOptions = self.makeTransactionQueryOptions(), transaction!.active else {
            let error = MongoKittenError(.commandFailure, reason: .inactiveTransaction)
            return eventLoop.newFailedFuture(error: error)
        }
        
        return session.execute(command: CommitTransactionCommand(), transaction: transactionQueryOptions).mapToResult(for: self)
    }
    
    public func abort() -> EventLoopFuture<Void> {
        // Crash if the transaction is `nil`, this is a bad violation of the API
        guard let transactionQueryOptions = self.makeTransactionQueryOptions(), transaction!.active else {
            let error = MongoKittenError(.commandFailure, reason: .inactiveTransaction)
            return eventLoop.newFailedFuture(error: error)
        }
        
        return session.execute(command: AbortTransactionCommand(), transaction: transactionQueryOptions).mapToResult(for: self)
    }
    
    public func close() {
//        database.sta
//        let command = EndSessionsCommand([session.sessionId], inNamespace: namespace)
    }
}

final class Transaction {
    let options: TransactionOptions
    var active = false
    var started = false
    var autocommit: Bool?
    let id: Int
    
    init(options: TransactionOptions, transactionId: Int) {
        self.options = options
        self.id = transactionId
    }
}

public struct TransactionOptions {
    // TODO: Read/Write concern and readPreference
    
    public init() {}
}
