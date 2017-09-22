extension Commands {
    
}

public struct Operation<O: Command>: Encodable, Command {
    public var operation: O
    
    public init(_ operation: O) {
        self.operation = operation
    }
    
    public func execute(on database: Database) throws -> Future<O.Result> {
        
    }
}

public protocol Command {
    associatedtype Result
}

public struct Aggregate<Result: Codable>: Command, _Command {
    var aggregate: String
    public var pipeline: AggregationPipeline
    public var cursor: CursorOptions
    public var maxTimeMS: UInt32
    public var bypassDocumentValidation: Bool?
    public var readConcern: ReadConcern?
    public var collation: Collation?
    
    init(collection: Collection, pipeline: AggregationPipeline) {
        self.aggregate = collection.name
        self.pipeline = pipeline
        self.cursor = CursorOptions()
    }
}

extension AggregationPipeline {
    public func makeOperation(for collection: Collection) -> Operation<Aggregate> {
        return Aggregate(collection: collectoin, pipeline: self)
    }
}

public struct CursorOptions: Codable {
    var batchSize: Int = 100
}
