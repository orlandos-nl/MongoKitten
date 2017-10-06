import Async
import BSON

extension Collection {
    public func find(
        _ filter: Query? = nil,
        sortedBy sort: Sort? = nil,
        projecting projection: Projection? = nil
    ) throws -> Future<Cursor<Document>> {
        var find = Find(on: self)
        find.filter = filter
        find.sort = sort
        find.projection = projection
        
        return try find.execute(on: database)
    }
    
    public func find(
        _ filter: Query? = nil,
        in range: Range<Int>,
        sortedBy sort: Sort? = nil,
        projecting projection: Projection? = nil
    ) throws -> Future<Cursor<Document>> {
        var find = Find(on: self)
        find.filter = filter
        find.sort = sort
        find.skip = range.lowerBound
        find.limit = range.upperBound - range.lowerBound
        find.projection = projection
        
        return try find.execute(on: database)
    }
    
    public func find(
        _ filter: Query? = nil,
        in range: ClosedRange<Int>,
        sortedBy sort: Sort? = nil,
        projecting projection: Projection? = nil
    ) throws -> Future<Cursor<Document>> {
        var find = Find(on: self)
        find.filter = filter
        find.sort = sort
        find.skip = range.lowerBound
        find.limit = (range.upperBound + 1) - range.lowerBound
        find.projection = projection
        
        return try find.execute(on: database)
    }
    
    public func find(
        _ filter: Query? = nil,
        in range: PartialRangeFrom<Int>,
        sortedBy sort: Sort? = nil,
        projecting projection: Projection? = nil
    ) throws -> Future<Cursor<Document>> {
        var find = Find(on: self)
        find.filter = filter
        find.sort = sort
        find.skip = range.lowerBound
        find.projection = projection
        
        return try find.execute(on: database)
    }
    
    public func find(
        _ filter: Query? = nil,
        in range: PartialRangeUpTo<Int>,
        sortedBy sort: Sort? = nil,
        projecting projection: Projection? = nil
    ) throws -> Future<Cursor<Document>> {
        var find = Find(on: self)
        find.filter = filter
        find.sort = sort
        find.limit = range.upperBound
        find.projection = projection
        
        return try find.execute(on: database)
    }
    
    public func find(
        _ filter: Query? = nil,
        in range: PartialRangeThrough<Int>,
        sortedBy sort: Sort? = nil,
        projecting projection: Projection? = nil
    ) throws -> Future<Cursor<Document>> {
        var find = Find(on: self)
        find.filter = filter
        find.sort = sort
        find.limit = range.upperBound + 1
        find.projection = projection
        
        return try find.execute(on: database)
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
    
    @discardableResult
    public func insert(_ document: Document) throws -> Future<Reply.Insert> {
        return try insertAll([document])
    }
    
    @discardableResult
    public func insertAll(_ documents: [Document]) throws -> Future<Reply.Insert> {
        let insert = Insert(documents, into: self)
        return try insert.execute(on: database)
    }
    
    @discardableResult
    public func update(_ query: Query = [:], to document: Document) throws -> Future<Void> {
        return try Update.Single(matching: query, to: document).execute(on: self).map { _ in }
    }
    
    @discardableResult
    public func upsert(_ query: Query = [:], to document: Document) throws -> Future<Void> {
        var update = Update.Single(matching: query, to: document)
        update.upsert = true
            
        return try update.execute(on: self).map { _ in }
    }
    
    @discardableResult
    public func updateAll(_ query: Query = [:], to document: Document) throws -> Future<Reply.Update> {
        return try Update.Single(matching: query, to: document).execute(on: self)
    }
    
    @discardableResult
    public func remove(_ query: Query = [:]) throws -> Future<Int> {
        return try Delete.Single(matching: query, limit: .one).execute(on: self)
    }
    
    @discardableResult
    public func removeAll(_ query: Query = [:]) throws -> Future<Int> {
        return try Delete.Single(matching: query, limit: .all).execute(on: self)
    }
    
    @discardableResult
    public func aggregate(_ pipeline: AggregationPipeline) throws -> Future<Cursor<Document>> {
        return try Aggregate(pipeline: pipeline, on: self).execute(on: self.database)
    }
}
