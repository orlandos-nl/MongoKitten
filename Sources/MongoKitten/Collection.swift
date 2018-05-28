import NIO
import Foundation

public typealias MongoCollection = Collection

public final class Collection {
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
    
    /// Initializes this collection with a database and name
    ///
    /// - parameter name: The collection name
    /// - parameter database: The database this `Collection` exists in
    internal init(named name: String, in database: Database) {
        self.name = name
        self.database = database
    }
    
    /// The full collection name, database + collection
    public var fullName: String {
        return "\(self.database.name).\(self.name)"
    }
    
    public func insert(_ document: Document) -> EventLoopFuture<InsertReply> {
        return InsertCommand([document], into: self).execute(on: connection)
    }
    
    public func insert(documents: [Document]) -> EventLoopFuture<InsertReply> {
        return InsertCommand(documents, into: self).execute(on: connection)
    }
    
    public func find(_ query: Query = [:]) -> EventLoopFuture<Cursor<Document>> {
        return FindOperation(filter: query, on: self).execute(on: connection)
    }
    
    public func find(
        _ query: Query = [:],
        inRange range: CountableRange<Int>
    ) -> EventLoopFuture<Cursor<Document>> {
        var operation = FindOperation(filter: query, on: self)
        operation.limit = range.upperBound - range.lowerBound
        operation.skip = range.lowerBound
        return operation.execute(on: connection)
    }
    
    public func find(
        _ query: Query = [:],
        inRange range: CountablePartialRangeFrom<Int>
    ) -> EventLoopFuture<Cursor<Document>> {
        var operation = FindOperation(filter: query, on: self)
        operation.skip = range.lowerBound
        return operation.execute(on: connection)
    }
    
    public func find(
        _ query: Query = [:],
        inRange range: CountableClosedRange<Int>
    ) -> EventLoopFuture<Cursor<Document>> {
        var operation = FindOperation(filter: query, on: self)
        operation.limit = range.upperBound - range.lowerBound
        operation.skip = range.lowerBound
        return operation.execute(on: connection)
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
    
    @discardableResult
    public func update(_ query: Query, to document: Document) -> EventLoopFuture<UpdateReply> {
        return UpdateCommand(query, to: document, in: self).execute(on: connection)
    }
    
    @discardableResult
    public func upsert(_ query: Query, to document: Document) -> EventLoopFuture<UpdateReply> {
        var update = UpdateCommand.Single(matching: query, to: document)
        update.upsert = true
        
        return UpdateCommand(update, in: self).execute(on: connection)
    }
    
    @discardableResult
    public func update(_ query: Query, setting set: [String: Primitive?]) -> EventLoopFuture<UpdateReply> {
        var setQuery = Document()
        var unsetQuery = Document()
        
        for (key, value) in set {
            if let value = value {
                setQuery[key] = value
            } else {
                unsetQuery[key] = ""
            }
        }
        
        return self.update(query, to: [
            "$set": setQuery,
            "$unset": unsetQuery
        ])
    }
    
    public func distinct(onKey key: String, filter: Query? = nil) -> EventLoopFuture<[Primitive]> {
        var distinct = DistinctCommand(onKey: key, into: self)
        distinct.query = filter
        return distinct.execute(on: connection)
    }
    
    public func aggregate(_ pipeline: Pipeline<[Document]>) -> EventLoopFuture<Cursor<Document>> {
        let command = AggregateCommand(pipeline: pipeline, in: self)
        return command.execute(on: connection)
    }
    
    public func aggregate<O>(_ pipeline: Pipeline<O>) -> EventLoopFuture<O> {
        let command = AggregateCommand(pipeline: pipeline, in: self)
        
        return command.execute(on: connection).thenThrowing(pipeline.transform)
    }
}
