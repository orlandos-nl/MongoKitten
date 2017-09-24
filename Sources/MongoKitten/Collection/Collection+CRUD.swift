import Schrodinger
import BSON

extension Collection {
    @discardableResult
    public func insert(contentsOf documents: [Document]) throws -> Future<Reply.Insert> {
        let insert = Insert(documents, into: self)
        return try insert.execute(on: database)
    }
    
    @discardableResult
    public func insert(_ document: Document) throws -> Future<Reply.Insert> {
        return try insert(contentsOf: [document])
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
    
    public func remove(_ query: Query = [:], limit: Int = 1) throws -> Future<Int> {
        return try Delete.Single(matching: query, limit: limit).execute(on: self)
    }
    
    public func aggregate(_ pipeline: AggregationPipeline) throws -> Future<Cursor<Document>> {
        return try Aggregate(pipeline: pipeline, on: self).execute(on: self.database)
    }
}
