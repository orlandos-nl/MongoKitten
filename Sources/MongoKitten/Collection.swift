import NIO
import Foundation

public final class Collection {
    public let name: String
    public let database: Database
    
    internal var reference: CollectionReference {
        return CollectionReference(to: self.name, inDatabase: self.database.name)
    }
    
    /// Initializes this collection with a database and name
    ///
    /// - parameter name: The collection name
    /// - parameter database: The database this `Collection` exists in
    internal init(named name: String, in database: Database) {
        self.name = name
        self.database = database
    }
    
    public func insert(_ document: Document) -> EventLoopFuture<InsertReply> {
        return InsertCommand([document], into: self).execute(on: self.database.connection)
    }
}
