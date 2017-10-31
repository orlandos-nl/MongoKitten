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
    
    public func execute(on connection: DatabaseConnection) throws -> Future<Cursor<Document>> {
        return try connection.execute(self) { reply, connection in
            guard
                let doc = reply.documents.first,
                Int(doc["ok"]) == 1,
                let cursor = Document(doc["cursor"])
            else {
                throw MongoError.cursorInitializationError(cursorDocument: reply.documents.first ?? [:])
            }
            
            return try Cursor<Document>(
                cursorDocument: cursor,
                collection: self.aggregate.name,
                database: self.targetCollection.database,
                connection: connection,
                chunkSize: self.cursor.batchSize,
                transform: { $0 }
            )
        }
    }
}

public struct CursorOptions: Codable {
    var batchSize: Int32 = 100
}
