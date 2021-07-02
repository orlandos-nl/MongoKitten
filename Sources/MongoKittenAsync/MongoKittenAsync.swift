import _NIOConcurrency
import NIO
import MongoClient
import MongoKitten

public struct MongoCluster {
    private let cluster: MongoKitten.MongoCluster
    public var heartbeatFrequency: TimeAmount {
        get { cluster.heartbeatFrequency }
        nonmutating set { cluster.heartbeatFrequency = newValue }
    }
    
    public var wireVersion: WireVersion? {
        cluster.wireVersion
    }
    
    public init(connectionString: String, awaitDiscovery: Bool) async throws {
        let settings = try ConnectionSettings(connectionString)
        cluster = try MongoKitten.MongoCluster(lazyConnectingTo: settings, on: MultiThreadedEventLoopGroup(numberOfThreads: 1))
        
        try await cluster.initialDiscovery.get()
    }
    
    public subscript(db: String) -> MongoDatabase {
        MongoDatabase(db: cluster[db])
    }
    
    public func onRediscover(perform: @escaping () -> ()) {
        self.cluster.didRediscover = perform
    }
    
    public func disconnect() async throws {
        try await cluster.disconnect().get()
    }
    
    public func reconnect() async throws {
        try await cluster.reconnect().get()
    }
    
    public func listDatabases() async throws -> [MongoDatabase] {
        return try await cluster.listDatabases().get().map(MongoDatabase.init)
    }
}

public struct MongoDatabase {
    fileprivate let db: MongoKitten.MongoDatabase
    
    public var name: String { db.name }
    public var isInTransaction: Bool { db.isInTransaction }
    
    public func listCollections() async throws -> [MongoCollection] {
        return try await db.listCollections().get().map(MongoCollection.init)
    }
    
    public subscript(collection: String) -> MongoCollection {
        MongoCollection(collection: db[collection])
    }
    
    public func drop() async throws {
        try await db.drop().get()
    }
}

public struct MongoCollection {
    fileprivate let collection: MongoKitten.MongoCollection
    
    public var name: String { collection.name }
    public var isInTransaction: Bool { collection.isInTransaction }
    
    public func drop() async throws {
        try await collection.drop().get()
    }
    
    public func count(_ query: Document? = nil) async throws -> Int {
        try await collection.count(query).get()
    }
    
    public func count<Query: MongoKittenQuery>(_ query: Query? = nil) async throws -> Int {
        try await collection.count(query).get()
    }
    
    @discardableResult
    public func deleteOne(where query: Document) async throws -> DeleteReply {
        try await collection.deleteOne(where: query).get()
    }
    
    @discardableResult
    public func deleteOne<Query: MongoKittenQuery>(where query: Query) async throws -> DeleteReply {
        try await collection.deleteOne(where: query).get()
    }
    
    @discardableResult
    public func deleteAll(where query: Document) async throws -> DeleteReply {
        try await collection.deleteAll(where: query).get()
    }
    
    @discardableResult
    public func deleteAll<Query: MongoKittenQuery>(where query: Query) async throws -> DeleteReply {
        try await collection.deleteAll(where: query).get()
    }
    
    public func find(_ query: Document = [:]) -> FindQueryBuilder {
        collection.find(query)
    }
    
    public func find<Query: MongoKittenQuery>(_ query: Query) -> FindQueryBuilder {
        collection.find(query)
    }

    public func find<D: Decodable>(_ query: Document = [:], as type: D.Type) -> MappedCursor<FindQueryBuilder, D> {
        collection.find(query, as: type)
    }

    public func findOne<D: Decodable>(_ query: Document = [:], as type: D.Type) async throws -> D? {
        try await collection.findOne(query, as: type).get()
    }
    
    @discardableResult
    public func insert(_ document: Document) async throws -> InsertReply {
        try await collection.insert(document).get()
    }
    
    @discardableResult
    public func insertMany(_ documents: [Document]) async throws -> InsertReply {
        try await collection.insertMany(documents).get()
    }
    
    @discardableResult
    public func insertEncoded<E: Encodable>(_ document: E) async throws -> InsertReply {
        try await collection.insertEncoded(document).get()
    }
    
    @discardableResult
    public func insertManyEncoded<E: Encodable>(_ documents: [E]) async throws -> InsertReply {
        try await collection.insertManyEncoded(documents).get()
    }
    
    @discardableResult
    public func updateOne(
        where query: Document,
        to document: Document
    ) async throws -> UpdateReply {
        try await collection.updateOne(where: query, to: document).get()
    }
    
    @discardableResult
    public func updateEncoded<E: Encodable>(
        where query: Document,
        to model: E
    ) async throws -> UpdateReply {
        try await collection.updateEncoded(where: query, to: model).get()
    }
    
    @discardableResult
    public func updateOne<Query: MongoKittenQuery>(
        where query: Query,
        to document: Document
    ) async throws -> UpdateReply {
        try await collection.updateEncoded(where: query, to: document).get()
    }
    
    @discardableResult
    public func updateEncoded<Query: MongoKittenQuery, E: Encodable>(
        where query: Query,
        to model: E
    ) async throws -> UpdateReply {
        try await collection.updateEncoded(where: query, to: model).get()
    }
    
    @discardableResult
    public func updateMany(
        where query: Document,
        to document: Document
    ) async throws -> UpdateReply {
        try await collection.updateManyEncoded(where: query, to: document).get()
    }
    
    @discardableResult
    public func updateManyEncoded<E: Encodable>(
        where query: Document,
        to model: E
    ) async throws -> UpdateReply {
        try await collection.updateManyEncoded(where: query, to: model).get()
    }
    
    @discardableResult
    public func updateMany<Query: MongoKittenQuery>(
        where query: Query,
        to document: Document
    ) async throws -> UpdateReply {
        try await collection.updateMany(where: query, to: document).get()
    }
    
    @discardableResult
    public func updateManyEncoded<Query: MongoKittenQuery, E: Encodable>(
        where query: Query,
        to model: E
    ) async throws -> UpdateReply {
        try await collection.updateManyEncoded(where: query, to: model).get()
    }
    
    @discardableResult
    public func updateMany(
        where query: Document,
        setting: Document?,
        unsetting: Document?
    ) async throws -> UpdateReply {
        try await collection.updateMany(where: query, setting: setting, unsetting: unsetting).get()
    }
    
    @discardableResult
    public func upsert(_ document: Document, where query: Document) async throws -> UpdateReply {
        try await collection.upsert(document, where: query).get()
    }
    
    @discardableResult
    public func upsertEncoded<E: Encodable>(_ model: E, where query: Document) async throws -> UpdateReply {
        try await collection.upsertEncoded(model, where: query).get()
    }
    
    @discardableResult
    public func upsert<Query: MongoKittenQuery>(_ document: Document, where query: Query) async throws -> UpdateReply {
        try await collection.upsert(document, where: query).get()
    }
    
    @discardableResult
    public func upsertEncoded<Query: MongoKittenQuery, E: Encodable>(_ model: E, where query: Query) async throws -> UpdateReply {
        try await collection.upsertEncoded(model, where: query).get()
    }
}

extension FinalizedCursor: AsyncSequence {
    public typealias Element = Base.Element
    
    public final class AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = FinalizedCursor.Element
        
        fileprivate let cursor: FinalizedCursor<Base>
        private var results = [Element]()
        
        fileprivate init(cursor: FinalizedCursor<Base>) {
            self.cursor = cursor
        }
        
        public func next() async throws -> Element? {
            if results.isEmpty {
                if cursor.isDrained {
                    return nil
                }
                
                try await results.append(contentsOf: cursor.nextBatch().get())
            }
            
            if results.isEmpty {
                return nil
            }
            
            return results.removeFirst()
        }
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(cursor: self)
    }
}
