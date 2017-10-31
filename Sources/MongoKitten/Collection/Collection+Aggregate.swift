import Async

extension Collection {
    @discardableResult
    public func aggregate(_ pipeline: AggregationPipeline) -> Future<Cursor<Document>> {
        let aggregate = Aggregate(pipeline: pipeline, on: self)
        
        return self.connectionPool.retain().flatten(aggregate.execute)
    }
}
