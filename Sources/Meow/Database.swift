import MongoCore
import MongoClient
import MongoKitten
import Dispatch
import NIO

/// A Meow wrapper around `MongoDatabase`, that allows subscripting with a `Model` type to get a `MeowCollection`
/// A MeowDatabase can exist in a transaction state, at which point it's actually a subclass named `MeowTransactionDatabase`.
///
/// Example usage:
///
///     let mongodb: MongoDatabase = mongoCluster["superapp"]
///     let meow = MeowDatabase(mongodb)
///     let users: MeowCollection<User> = meow[User.self]
public class MeowDatabase {
    public let raw: MongoDatabase
    
    public init(_ database: MongoDatabase) {
        self.raw = database
    }
    
    public func collection<M: BaseModel>(for model: M.Type) -> MeowCollection<M> {
        return MeowCollection<M>(database: self, named: M.collectionName)
    }
    
    public subscript<M: BaseModel>(type: M.Type) -> MeowCollection<M> {
        return collection(for: type)
    }
    
    /// Creates a transaction database, with which the same queries can be done with the same APis as this object.
    /// If an error in thrown within `perform`, the transaction is aborted
    /// It's automaticalyl committed if successful
    public func withTransaction<T>(
        with options: MongoSessionOptions = .init(),
        transactionOptions: MongoTransactionOptions? = nil,
        perform: (MeowTransactionDatabase) async throws -> T
    ) async throws -> T {
        let transaction = try await raw.startTransaction(autoCommitChanges: false, with: options, transactionOptions: transactionOptions)
        let meowDatabase = MeowTransactionDatabase(transaction)
        
        do {
            let result = try await perform(meowDatabase)
            try await transaction.commit()
            return result
        } catch {
            try await transaction.abort()
            throw error
        }
    }
}

/// A Meow wrapper around `MongoDatabase`, that allows subscripting with a `Model` type to get a `MeowCollection`.
/// A MeowTransactionDatabase is used to do all operations within a transaction context
///
/// Example usage:
///
///     let mongodb: MongoDatabase = mongoCluster["superapp"]
///     let meow = MeowDatabase(mongodb)
///     let users: MeowCollection<User> = meow[User.self]
public final class MeowTransactionDatabase: MeowDatabase {
    private let transaction: MongoTransactionDatabase
    
    fileprivate init(_ transaction: MongoTransactionDatabase) {
        self.transaction = transaction
        
        super.init(transaction)
    }
    
    /// Commits changes
    public func commit() async throws {
        try await transaction.commit()
    }
}
