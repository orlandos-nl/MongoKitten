import Async

public struct Find<C: Codable>: Command, Operation {
    var targetCollection: MongoCollection<C> {
        return find
    }
    
    public let find: Collection<C>
    public var batchSize: Int32 = 100
    
    public var readConcern: ReadConcern?
    public var collation: Collation?
    public var filter: Query?
    public var sort: Sort?
    public var skip: Int?
    public var limit: Int?
    public var projection: Projection?
    
    static var writing: Bool { return false }
    static var emitsCursor: Bool { return true }
    
    public init(on collection: Collection<C>) {
        self.find = collection
        
        // Collection defaults
        self.readConcern = collection.default.readConcern
        self.collation = collection.default.collation
    }
    
    public func execute(on connection: DatabaseConnection) -> Cursor<C> {
        let cursor = Cursor(collection: find, connection: connection)
        
        connection.execute(self, expecting: Reply.Cursor.self).do { spec in
            cursor.initialize(to: spec.cursor)
        }.catch(cursor.error)
        
        return cursor
    }
}

public struct FindOne<C: Codable> {
    let collection: Collection<C>
    public var readConcern: ReadConcern?
    public var collation: Collation?
    public var filter: Query?
    public var sort: Sort?
    public var skip: Int?
    public var projection: Projection?
    
    public init(for collection: Collection<C>) {
        self.collection = collection
        
        self.readConcern = collection.default.readConcern
        self.collation = collection.default.collation
    }
    
    public func execute(on connection: DatabaseConnection) -> Future<Document?> {
        var find = Find(on: collection)
        find.batchSize = 1
        find.limit = 1
        
        find.readConcern = readConcern
        find.collation = collation
        find.filter = filter
        find.sort = sort
        find.skip = skip
        find.projection = projection
        
        let cursor = find.execute(on: connection)
        let promise = Promise<Document?>()
        
        cursor.drain { doc, _ in
            promise.complete(doc)
        }.upstream?.request()
        
        return promise.future
    }
}
