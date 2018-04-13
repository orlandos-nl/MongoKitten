import BSON
import Async

public struct Insert<C: Codable>: Command, Operation {
    var targetCollection: MongoCollection<C> {
        return insert
    }
    
    public let insert: String
    public var documents: [C]
    public var ordered: Bool?
    public var writeConcern: WriteConcern?
    public var bypassDocumentValidation: Bool?
    
    static var writing: Bool {
        return true
    }
    
    static var emitsCursor: Bool {
        return false
    }
    
    public init(_ documents: [C], into collection: Collection<C>) {
        self.insert = collection
        self.documents = Array(documents)
        
        self.writeConcern = collection.default.writeConcern
    }
    
    @discardableResult
    public func execute(on connection: DatabaseConnection) -> Future<Reply.Insert?> {
        return connection.execute(self, preferring: Reply.Insert.self) { reply, _ in
            if let reply = reply {
                guard reply.ok == 1 else {
                    throw reply
                }
            }
            
            return reply
        }
    }
}

extension Reply {
    public struct Insert: Codable, Error {
        public var n: Int?
        public var ok: Int
        public var errmsg: String?
        public var writeErrors: [Errors.Write]?
        public var writeConcernError: [Errors.WriteConcern]?
    }
}
