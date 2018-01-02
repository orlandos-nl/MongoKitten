import BSON
import Async

public struct Update<C: Codable>: Command, Operation {
    public struct Single: Encodable {
        public var q: Query
        public var u: Document
        public var collation: Collation?
        public var upsert: Bool?
        public var multi: Bool?
        
        public init(matching query: Query, to document: Document) {
            self.q = query
            self.u = document
        }
        
        public func execute(on connection: DatabaseConnection, collection: Collection<C>) -> Future<Reply.Update> {
            let updates = Update(self, in: collection)
            
            return updates.execute(on: connection)
        }
    }
    
    var targetCollection: MongoCollection<C> {
        return update
    }
    
    public let update: Collection<C>
    public var updates: [Single]
    public var ordered: Bool?
    public var writeConcern: WriteConcern?
    public var bypassDocumentValidation: Bool?
    
    static var writing: Bool { return true }
    static var emitsCursor: Bool { return false }
    
    public init(matching query: Query, to document: Document, in collection: Collection<C>) {
        self.init(
            Single(matching: query, to: document),
            in: collection
        )
    }
    
    public init(_ updates: Single..., in collection: Collection<C>) {
        self.init(updates, in: collection)
    }
    
    public init<S: Sequence>(_ updates: S, in collection: Collection<C>) where S.Element == Single {
        self.update = collection
        self.updates = Array(updates)
        
        self.writeConcern = collection.default.writeConcern
    }
    
    public func execute(on connection: DatabaseConnection) -> Future<Reply.Update> {
        return connection.execute(self, expecting: Reply.Update.self) { reply, _ in
            guard reply.ok == 1 else {
                throw reply
            }
            
            return reply
        }
    }
}

extension Reply {
    public struct Update: Codable, Error {
        public var n: Int?
        public var ok: Int
        public var nModified: Int
        public var upserted: [Document]? // TODO: type-safe? We cannot (easily) decode the _id
        public var writeErrors: [Errors.Write]?
        public var writeConcernError: [Errors.WriteConcern]?
    }
}
