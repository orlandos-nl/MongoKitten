import BSON
import Schrodinger

public struct Delete: Command, Operation {
    public struct Single: Codable {
        public var q: Query
        public var limit: RemoveLimit
        public var collation: Collation?
        
        public init(matching query: Query, limit: RemoveLimit = .one) {
            self.q = query
            self.limit = limit
        }
        
        public func execute(on collection: Collection) throws -> Future<Int> {
            let deletes = Delete([self], from: collection)
            
            return try deletes.execute(on: collection.database)
        }
    }
    
    let delete: String
    public var deletes: [Single]
    public var ordered: Bool?
    public var writeConcern: WriteConcern?
    public var bypassDocumentValidation: Bool?
    
    static var writing = true
    static var emitsCursor = false
    
    public init(_ deletes: [Single], from collection: Collection) {
        self.delete = collection.name
        self.deletes = Array(deletes)
        
        self.writeConcern = collection.default.writeConcern
    }
    
    @discardableResult
    public func execute(on database: Database) throws -> Future<Int> {
        return try database.execute(self, expecting: Reply.Delete.self) { reply, _ in
            guard let n = reply.n, reply.ok == 1 else {
                throw reply
            }
            
            return n
        }
    }
}

extension Reply {
    public struct Delete: Codable, Error {
        public var n: Int?
        public var ok: Int
        public var writeErrors: [Errors.Write]?
        public var writeConcernError: [Errors.WriteConcern]?
    }
}

