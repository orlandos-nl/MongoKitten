import Async

public struct Aggregate: Command, Operation {
    var targetCollection: MongoCollection {
        return aggregate
    }
    
    public let aggregate: Collection
    public var pipeline: AggregationPipeline
    public var cursor: CursorOptions
    public var maxTimeMS: UInt32?
    public var bypassDocumentValidation: Bool?
    public var readConcern: ReadConcern?
    public var collation: Collation?
    
    static var writing = true
    static var emitsCursor = true
    
    public init(pipeline: AggregationPipeline, on collection: Collection) {
        self.aggregate = collection
        self.pipeline = pipeline
        self.cursor = CursorOptions()
        
        // Collection defaults
        self.readConcern = collection.default.readConcern
        self.collation = collection.default.collation
    }
    
    public func execute(on connection: DatabaseConnection)  -> Future<Cursor> {
        return connection.execute(self, expecting: Reply.Cursor.self).map(to: Cursor.self) { cursor in
            return try Cursor(
                cursor: cursor.cursor,
                collection: self.aggregate,
                database: self.targetCollection.database,
                connection: connection,
                chunkSize: self.cursor.batchSize
            )
        }
    }
}

public struct CursorOptions: Codable {
    var batchSize: Int32 = 100
}
