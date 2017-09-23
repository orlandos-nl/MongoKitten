import Schrodinger

public struct Aggregate: Command, Operation {
    let aggregate: String
    public var pipeline: AggregationPipeline
    public var cursor: CursorOptions
    public var maxTimeMS: UInt32?
    public var bypassDocumentValidation: Bool?
    public var readConcern: ReadConcern?
    public var collation: Collation?
    
    static var writing = true
    static var emitsCursor = true
    
    public init(pipeline: AggregationPipeline, on collection: Collection) {
        self.aggregate = collection.name
        self.pipeline = pipeline
        self.cursor = CursorOptions()
        
        // Collection defaults
        self.readConcern = collection.default.readConcern
        self.collation = collection.default.collation
    }
    
    public func execute(on database: Database) throws -> Future<Cursor<Document>> {
        return try database.execute(self) { reply, connection in
            let collection = database[self.aggregate]
            
            return try Cursor.init(
                namespace: collection.namespace,
                collection: collection.name,
                database: database,
                connection: connection,
                reply: reply,
                chunkSize: self.cursor.batchSize,
                transform: { $0 }
            )
        }
    }
}

public struct CursorOptions: Codable {
    var batchSize: Int32 = 100
}
