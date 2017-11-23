import Async

public struct Find: Command, Operation {
    var targetCollection: MongoCollection {
        return find
    }
    
    public let find: Collection
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
        self.find = collection
        
        // Collection defaults
        self.readConcern = collection.default.readConcern
        self.collation = collection.default.collation
    }
    
    public func execute(on database: DatabaseConnection) throws -> Future<Cursor> {
        return try database.execute(self, expecting: Reply.Cursor.self) { cursor, connection in
            return try Cursor(
                cursor: cursor.cursor,
                collection: self.find.name,
                database: self.targetCollection.database,
                connection: connection,
                chunkSize: self.batchSize
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
    
    public func execute(on connection: DatabaseConnection) throws -> Future<Document?> {
        var find = Find(on: collection)
        find.batchSize = 1
        find.limit = 1
        
        find.readConcern = readConcern
        find.collation = collation
        find.filter = filter
        find.sort = sort
        find.skip = skip
        find.projection = projection
        
        return try find.execute(on: connection).flatMap { cursor in
            let promise = Promise<Document?>()
            
            cursor.drain { doc in
                promise.complete(doc)
            }.catch(onError: promise.fail)
            
            cursor.finally {
                promise.complete(nil)
            }
            
            cursor.start()
            
            return promise.future
        }
    }
}
