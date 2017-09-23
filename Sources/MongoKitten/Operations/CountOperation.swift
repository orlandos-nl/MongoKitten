import Schrodinger

public struct Count: Command, Operation {
    let count: String
    public var query: Query?
    public var skip: Int?
    public var limit: Int?
    public var readConcern: ReadConcern?
    public var collation: Collation?
    
    static var writing = false
    static var emitsCursor = false
    
    public init(on collection: Collection) {
        self.count = collection.name
        
        // Collection defaults
        self.readConcern = collection.default.readConcern
        self.collation = collection.default.collation
    }
    
    public func execute(on database: Database) throws -> Future<Int> {
        return try database.execute(self, expecting: Reply.Count.self) { reply, _ in
            guard reply.ok == 1 else {
                throw Errors.Count(from: reply)
            }
            
            return reply.n
        }
    }
}

extension Reply {
    struct Count: Decodable {
        var n: Int
        var ok: Int
    }
}

extension Errors {
    public struct Count: Error {
        // TODO:
        
        init(from reply: Reply.Count) {
            // TODO: 
        }
    }
}
