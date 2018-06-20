import NIO
import Foundation

public final class Collection: FutureConvenienceCallable {
    public let name: String
    public let database: Database
    
    var eventLoop: EventLoop {
        return connection.eventLoop
    }
    
    internal var connection: MongoDBConnection {
        return self.database.connection
    }
    
    public var objectIdGenerator: ObjectIdGenerator {
        return connection.sharedGenerator
    }
    
    internal var reference: Namespace {
        return Namespace(to: self.name, inDatabase: self.database.name)
    }
    
    /// Initializes this collection with by the database it's in and the collection name
    internal init(named name: String, in database: Database) {
        self.name = name
        self.database = database
    }
    
    /// The full collection name, database + collection
    public var fullName: String {
        return "\(self.database.name).\(self.name)"
    }
    
    @discardableResult
    public func insert(_ document: Document) -> EventLoopFuture<InsertReply> {
        return InsertCommand([document], into: self).execute(on: connection)
    }
    
    @discardableResult
    public func insert(documents: [Document]) -> EventLoopFuture<InsertReply> {
        return InsertCommand(documents, into: self).execute(on: connection)
    }
    
    public func find(_ query: Query = [:]) -> FindCursor {
        return FindCursor(operation: FindOperation(filter: query, on: self), on: self)
    }
    
    public func findOne(_ query: Query = [:]) -> EventLoopFuture<Document?> {
        var operation = FindOperation(filter: query, on: self)
        operation.limit = 1
        
        return FindCursor(operation: operation, on: self).getFirstResult()
    }
    
    public func count(_ query: Query? = nil) -> EventLoopFuture<Int> {
        return CountCommand(query, in: self).execute(on: connection)
    }
    
    public func deleteAll(_ query: Query = [:]) -> EventLoopFuture<Int> {
        let delete = DeleteCommand.Single(matching: query, limit: .all)
        
        return DeleteCommand([delete], from: self).execute(on: connection)
    }
    
    public func deleteOne(_ query: Query = [:]) -> EventLoopFuture<Int> {
        let delete = DeleteCommand.Single(matching: query, limit: .one)
        
        return DeleteCommand([delete], from: self).execute(on: connection)
    }
    
    // TODO: Make the future fail when the reply indicates an error
    @discardableResult
    public func update(_ query: Query, to document: Document, multiple: Bool? = nil) -> EventLoopFuture<UpdateReply> {
        return UpdateCommand(query, to: document, in: self, multiple: multiple).execute(on: connection)
    }
    
    @discardableResult
    public func upsert(_ query: Query, to document: Document) -> EventLoopFuture<UpdateReply> {
        var update = UpdateCommand.Single(matching: query, to: document)
        update.upsert = true
        
        return UpdateCommand(update, in: self).execute(on: connection)
    }
    
    @discardableResult
    public func update(_ query: Query, setting set: [String: Primitive?], multiple: Bool? = nil) -> EventLoopFuture<UpdateReply> {
        guard set.count > 0 else {
            return eventLoop.newFailedFuture(error: MongoKittenError(.cannotFormCommand, reason: .nothingToDo))
        }
        
        var setQuery = Document()
        var unsetQuery = Document()
        
        for (key, value) in set {
            if let value = value {
                setQuery[key] = value
            } else {
                unsetQuery[key] = ""
            }
        }
        
        let updateDocument: Document = [
            "$set": setQuery.count > 0 ? setQuery : nil,
            "$unset": unsetQuery.count > 0 ? unsetQuery : nil
        ]
        
        return self.update(query, to: updateDocument, multiple: multiple)
    }
    
    // TODO: Discuss `filter` vs `query` as argument name
    public func distinct(onKey key: String, filter: Query? = nil) -> EventLoopFuture<[Primitive]> {
        var distinct = DistinctCommand(onKey: key, into: self)
        distinct.query = filter
        return distinct.execute(on: connection)
    }
    
    /// Calculates aggregate values for the data in a collection or a view.
    ///
    /// - parameter comment: Users can specify an arbitrary string to help trace the operation through the database profiler, currentOp, and logs.
    public func aggregate(comment: String? = nil) -> AggregateCursor<Document> {
        var cursor = AggregateCursor(on: self)
        
        if let comment = comment {
            cursor.operation.comment = comment
        }
        
        return cursor
    }
    
//    public func aggregate(_ pipeline: Pipeline<[Document]>) -> Cursor<Document> {
//        let command = AggregateCommand(pipeline: pipeline, in: self)
//        return command.execute(on: connection)
//    }
//
//    public func aggregate<O>(_ pipeline: Pipeline<O>) -> O.Output {
//        let command = AggregateCommand(pipeline: pipeline, in: self)
//
//        return command.execute(on: connection).thenThrowing(pipeline.transform)
//    }
}
