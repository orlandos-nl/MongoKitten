import Schrodinger

extension Commands {
    
}

public protocol OperationType {
    associatedtype Result
    
    func execute(on database: Database) throws -> Future<Result>
}

public struct Operation<OT: OperationType> {
    public let operation: OT
    public let collection: Collection
    
    init(_ operation: OT, for collection: Collection) {
        self.operation = operation
        self.collection = collection
    }
}

public struct Aggregate: Command, OperationType {
    let collection: Collection
    public var pipeline: AggregationPipeline
    public var cursor: CursorOptions
    public var maxTimeMS: UInt32
    public var bypassDocumentValidation: Bool?
    public var readConcern: ReadConcern?
    public var collation: Collation?
    
    init(collection: Collection, pipeline: AggregationPipeline) {
        self.collection = collection
        self.pipeline = pipeline
        self.cursor = CursorOptions()
    }
    
    public func execute(on database: Database) throws -> Future<Cursor<Document>> {
        let connection = try self.database.server.reserveConnection(authenticatedFor: self.collection.database)
        
        return try database.execute(self, on: connection) { reply in
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
