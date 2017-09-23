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
    
    public init(_ updates: Update..., on collection: Collection) {
        self.update = collection.name
        self.updates = updates
    }
    
    public init<S: Sequence>(_ updates: S, on collection: Collection) where S.Element == Update {
        self.update = collection.name
        self.updates = Array(updates)
    }
    
    public func execute(on database: Database) throws -> Future<Cursor<Document>> {
        return try database.execute(self) { reply, connection in
            let collection = database[self.find]
            
            return try Cursor.init(
                namespace: collection.fullName,
                collection: collection.name,
                database: database,
                connection: connection,
                reply: reply,
                chunkSize: self.batchSize,
                transform: { $0 }
            )
        }
    }
}
