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
    
    public func execute(on connection: DatabaseConnection) -> Cursor {
        let cursor = Cursor(collection: aggregate, connection: connection)
        
        connection.execute(self, expecting: Reply.Cursor.self).do { spec in
            cursor.initialize(to: spec.cursor)
        }.catch(cursor.error)
        
        return cursor
    }
}

public struct CursorOptions: Codable {
    var batchSize: Int32 = 100
}
