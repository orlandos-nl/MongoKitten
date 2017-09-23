import Schrodinger

public struct Find: Command, Operation {
    let find: String
    public var batchSize: Int32 = 100
    
    public var readConcern: ReadConcern?
    public var collation: Collation?
    public var filter: Query?
    public var sort: Sort?
    public var skip: Int?
    public var limit: Int?
    public var projection: Projection?
    
    static var writing = false
    static var emitsCursor = true
    
    public init(on collection: Collection) {
        self.find = collection.name
        
        // Collection defaults
        self.readConcern = collection.default.readConcern
        self.collation = collection.default.collation
    }
    
    public func execute(on database: Database) throws -> Future<Cursor<Document>> {
        return try database.execute(self) { reply, connection in
            let collection = database[self.find]
            
            return try Cursor.init(
                namespace: collection.namespace,
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
