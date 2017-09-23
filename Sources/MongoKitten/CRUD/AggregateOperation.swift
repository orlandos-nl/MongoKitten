import Schrodinger

public struct Aggregate: Command, OperationType {
    let aggregate: String
    public var pipeline: AggregationPipeline
    public var cursor: CursorOptions
    public var maxTimeMS: UInt32
    public var bypassDocumentValidation: Bool?
    public var readConcern: ReadConcern?
    public var collation: Collation?
    
    static var writing = true
    static var emitsCursor = true
    
    public init(collection: Collection, pipeline: AggregationPipeline) {
        self.aggregate = collection.name
        self.pipeline = pipeline
        self.cursor = CursorOptions()
        
        // Collection defaults
        self.readConcern = collection.default.readConcern
        self.collation = collection.default.collation
    }
    
    public func execute(on database: Database) throws -> Future<Cursor<Document>> {
        let connection = try self.database.server.reserveConnection(authenticatedFor: self.database)
        
        return try database.execute(self) { reply, connection in
            let collection = database[aggregate]
            
            return Cursor.init(
                namespace: collection.fullName,
                collection: collection.name,
                database: database,
                connection: connection,
                reply: reply,
                chunkSize: cursor.batchSize,
                transform: { $0 }
            )
        }
    }
}

extension AggregationPipeline {
    public func makeOperation(for collection: Collection) -> Aggregate {
        return Aggregate(collection: collection, pipeline: self)
    }
}

public struct CursorOptions: Codable {
    var batchSize: Int = 100
}
