import Schrodinger
import BSON

extension Collection {
    public func aggregate(_ pipeline: AggregationPipeline) throws -> Future<Cursor<Document>> {
        return try Aggregate(pipeline: pipeline, on: self).execute(on: self.database)
    }
}
