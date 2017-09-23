import Schrodinger

public struct Count: Command, OperationType {
    let count: String
    public var query: Query?
    public var skip: Int?
    public var limit: Int?
    public var readConcern: ReadConcern?
    public var collation: Collation?
    
    public init(collection: Collection, pipeline: AggregationPipeline) {
        self.aggregate = collection.name
        self.pipeline = pipeline
        self.cursor = CursorOptions()
        
        // Collection defaults
        self.readConcern = collection.default.readConcern
        self.collation = collection.default.collation
    }
    
    public func execute(on database: Database) throws -> Future<Int> {
        return try database.execute(self, expecting: Reply.Count.self) { reply in
            guard reply.ok == 1 else {
                throw Errors.Count(from: reply)
            }
            
            return reply.n
        }
    }
}

extension Reply {
    struct Count {
        var n: Int
        var ok: Int
    }
}

extension Errors {
    public struct Count {
        // TODO:
        
        init(from reply: Reply.Count) {
            // TODO: 
        }
    }
}
