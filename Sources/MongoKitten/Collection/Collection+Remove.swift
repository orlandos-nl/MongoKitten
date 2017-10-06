import Async

extension Collection {
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
