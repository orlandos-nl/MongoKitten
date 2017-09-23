import BSON
import Schrodinger

public struct Updates: Command, Operation {
    public struct Update: Codable {
        public var q: Query
        public var u: Document
        public var collation: Collation?
        public var upsert: Bool?
        public var multi: Bool?
        
        public init(matching query: Query, to document: Document) {
            self.q = query
            self.u = document
        }
        
        public func execute(on collection: Collection) throws -> Future<Void> {
            let updates = Updates(on: collection)
            
            try updates.execute(on: database)
        }
    }
    
    let update: String
    public var updates: [Update]
    public var ordered: Bool?
    public var writeConcern: WriteConcern?
    public var bypassDocumentValidation: Bool?
    
    static var writing = true
    static var emitsCursor = false
    
    public init(matching query: Query, to document: Document, on collection: Collection) {
        self.init(
            Update(matching: query, to: document),
            on: collection
        )
    }
    
    public init(_ updates: Update..., on collection: Collection) {
        self.update = collection.name
        self.updates = updates
    }
    
    public init<S: Sequence>(_ updates: S, on collection: Collection) where S.Element == Update {
        self.update = collection.name
        self.updates = Array(updates)
    }
    
    public func execute(on database: Database) throws -> Future<Reply.Update> {
        return try database.execute(self, expecting: Reply.Update.self) { reply, _ in
            guard reply.ok == 1 else {
                throw reply
            }
            
            return reply.n
        }
    }
}

extension Reply {
    public struct Update: Codable, Error {
        public var n: Int
        public var ok: Int
        public var nModified: Int
        public var upserted: [Document]? // TODO: type-safe? We cannot (easily) decode the _id
        public var writeErrors: [Errors.Write]?
        public var writeConcernError: [Errors.WriteConcern]
    }
}
