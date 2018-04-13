import Async

public struct Count<C: Codable>: Command, Operation {
    let targetCollection: MongoCollection<C>
    
    public let count: String
    public var query: Query?
    public var skip: Int?
    public var limit: Int?
    public var readConcern: ReadConcern?
    public var collation: Collation?
    
    static var writing: Bool { return false }
    static var emitsCursor: Bool { return false }
    
    public init(on collection: Collection<C>) {
        self.count = collection.name
        self.targetCollection = collection
        
        // Collection defaults
        self.readConcern = collection.default.readConcern
        self.collation = collection.default.collation
    }
    
    public func execute(on connection: DatabaseConnection) -> Future<Int> {
        return connection.execute(self, expecting: Reply.Count.self) { reply, _ in
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
