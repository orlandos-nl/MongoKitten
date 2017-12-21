import Async

extension Collection {
    @discardableResult
    public func aggregate(_ pipeline: AggregationPipeline) -> Future<Cursor> {
        let aggregate = Aggregate(pipeline: pipeline, on: self)
        
        return self.connectionPool.retain().flatMap(to: Cursor.self, aggregate.execute)
    }
}
