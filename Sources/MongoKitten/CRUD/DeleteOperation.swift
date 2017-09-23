import BSON
import Schrodinger

public struct Delete: Command, Operation {
    public struct Single: Codable {
        public var q: Query
        public var limit: Int?
        public var collation: Collation?
        
        public init(matching query: Query) {
            self.q = query
        }
    }
    
    let delete: String
    public var deletes: [Single]
    public var ordered: Bool?
    public var writeConcern: WriteConcern?
    public var bypassDocumentValidation: Bool?
    
    static var writing = true
    static var emitsCursor = false
    
    public init(_ deletes: [Single], into collection: Collection) {
        self.delete = collection.name
        self.deletes = Array(deletes)
        
        self.writeConcern = collection.default.writeConcern
    }
    
    @discardableResult
    public func execute(on database: Database) throws -> Future<Reply.Insert> {
        return try database.execute(self, expecting: Reply.Delete.self) { reply, _ in
            guard reply.ok == 1 else {
                throw reply
            }
            
            return reply
        }
    }
}

extension Reply {
    public struct Delete: Codable, Error {
        public var n: Int
        public var ok: Int
        public var writeErrors: [Errors.Write]?
        public var writeConcernError: [Errors.WriteConcern]
    }
}

