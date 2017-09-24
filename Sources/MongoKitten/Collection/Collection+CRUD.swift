import Schrodinger
import BSON

extension Collection {
    @discardableResult
    public func insert(_ document: Document) throws -> Future<Reply.Insert> {
        return try insertAll([document])
    }
    
    @discardableResult
    public func insertAll(_ documents: [Document]) throws -> Future<Reply.Insert> {
        let insert = Insert(documents, into: self)
        return try insert.execute(on: database)
    }
    
    public func findOne(
        _ filter: Query? = nil,
        sortedBy sort: Sort? = nil,
        projecting projection: Projection? = nil
    ) throws -> Future<Document?> {
        var findOne = FindOne(for: self)
        findOne.filter = filter
        findOne.sort = sort
        findOne.projection = projection
        
        return try findOne.execute(on: database)
    }
    
    public func count(_ query: Query? = nil) throws -> Future<Int> {
        var count = Count(on: self)
        count.query = query
        
        return try count.execute(on: database)
    }
    
    public func remove(_ query: Query = [:]) throws -> Future<Int> {
        return try Delete.Single(matching: query, limit: .one).execute(on: self)
    }
    
    public func removeAll(_ query: Query = [:]) throws -> Future<Int> {
        return try Delete.Single(matching: query, limit: .all).execute(on: self)
    }
    
    public func aggregate(_ pipeline: AggregationPipeline) throws -> Future<Cursor<Document>> {
        return try Aggregate(pipeline: pipeline, on: self).execute(on: self.database)
    }
}
