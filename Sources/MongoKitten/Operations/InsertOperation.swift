import BSON
import Schrodinger

public struct Insert: Command, Operation {
    let insert: String
    public var documents: [Document]
    public var ordered: Bool?
    public var writeConcern: WriteConcern?
    public var bypassDocumentValidation: Bool?
    
    static var writing = true
    static var emitsCursor = false
    
    public init(_ documents: [Document], into collection: Collection) {
        self.insert = collection.name
        self.documents = Array(documents)
        
        self.writeConcern = collection.default.writeConcern
    }
    
    @discardableResult
    public func execute(on database: Database) throws -> Future<Reply.Insert> {
        return try database.execute(self, expecting: Reply.Insert.self) { reply, _ in
            guard reply.ok == 1 else {
                throw reply
            }
            
            return reply
        }
    }
}

extension Reply {
    public struct Insert: Codable, Error {
        public var n: Int
        public var ok: Int
        public var writeErrors: [Errors.Write]?
        public var writeConcernError: [Errors.WriteConcern]
    }
}
