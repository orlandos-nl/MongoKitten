extension Commands {
    struct Aggregate: Encodable {
        var aggregate: String
        var pipeline: Document
        var cursor: CursorOptions
        var maxTimeMS: UInt32
        var bypassDocumentValidation: Bool?
        var readConcern: ReadConcern?
        var collation: Collation?
        
        init(collection: Collection, pipeline: AggregationPipeline, cursor: CursorOptions) {
            self.aggregate = collection.name
            self.pipeline = pipeline
            self.cursor = cursor
        }
    }
}

struct CursorOptions: Codable {
    var batchSize: Int = 100
}
