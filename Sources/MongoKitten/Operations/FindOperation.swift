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
            guard
                let doc = reply.documents.first,
                Int(doc["ok"]) == 1,
                let cursor = Document(doc["cursor"])
            else {
                throw MongoError.cursorInitializationError(cursorDocument: reply.documents.first ?? [:])
            }
            
            return try Cursor<Document>(
                cursorDocument: cursor,
                collection: self.find,
                database: database,
                connection: connection,
                chunkSize: self.batchSize,
                transform: { $0 }
            )
        }
    }
}

public struct FindOne {
    let collection: Collection
    public var readConcern: ReadConcern?
    public var collation: Collation?
    public var filter: Query?
    public var sort: Sort?
    public var skip: Int?
    public var projection: Projection?
    
    public init(for collection: Collection) {
        self.collection = collection
        
        self.readConcern = collection.default.readConcern
        self.collation = collection.default.collation
    }
    
    public func execute(on database: Database) throws -> Future<Document?> {
        var find = Find(on: collection)
        find.batchSize = 1
        find.limit = 1
        
        find.readConcern = readConcern
        find.collation = collation
        find.filter = filter
        find.sort = sort
        find.skip = skip
        find.projection = projection
        
        return try find.execute(on: database).map { cursor in
            return cursor.data.first
        }
    }
}
