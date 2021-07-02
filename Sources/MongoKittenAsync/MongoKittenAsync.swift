import _NIOConcurrency
import NIO
import MongoClient
import MongoKitten

extension MongoCluster {
    public struct Async {
        public let nio: MongoCluster
        public var heartbeatFrequency: TimeAmount {
            get { nio.heartbeatFrequency }
            nonmutating set { nio.heartbeatFrequency = newValue }
        }
        
        public var wireVersion: WireVersion? {
            nio.wireVersion
        }
        
        public init(connectionString: String, awaitDiscovery: Bool) async throws {
            let settings = try ConnectionSettings(connectionString)
            nio = try MongoCluster(lazyConnectingTo: settings, on: MultiThreadedEventLoopGroup(numberOfThreads: 1))
            
            try await nio.initialDiscovery.get()
        }
        
        public subscript(db: String) -> MongoDatabase.Async {
            MongoDatabase.Async(nio: nio[db])
        }
        
        public func onRediscover(perform: @escaping () -> ()) {
            self.nio.didRediscover = perform
        }
        
        public func disconnect() async throws {
            try await nio.disconnect().get()
        }
        
        public func reconnect() async throws {
            try await nio.reconnect().get()
        }
        
        public func listDatabases() async throws -> [MongoDatabase.Async] {
            return try await nio.listDatabases().get().map(MongoDatabase.Async.init)
        }
    }
}

extension MongoDatabase {
    public struct Async {
        public let nio: MongoDatabase
        
        public var name: String { nio.name }
        public var isInTransaction: Bool { nio.isInTransaction }
        
        public func listCollections() async throws -> [MongoCollection.Async] {
            return try await nio.listCollections().get().map(MongoCollection.Async.init)
        }
        
        public subscript(collection: String) -> MongoCollection.Async {
            MongoCollection.Async(nio: nio[collection])
        }
        
        public func drop() async throws {
            try await nio.drop().get()
        }
    }
}

extension MongoCollection {
    public struct Async {
        public let nio: MongoCollection
        
        public var name: String { nio.name }
        public var isInTransaction: Bool { nio.isInTransaction }
        
        public func drop() async throws {
            try await nio.drop().get()
        }
        
        public func count(_ query: Document? = nil) async throws -> Int {
            try await nio.count(query).get()
        }
        
        public func count<Query: MongoKittenQuery>(_ query: Query? = nil) async throws -> Int {
            try await nio.count(query).get()
        }
        
        @discardableResult
        public func deleteOne(where query: Document) async throws -> DeleteReply {
            try await nio.deleteOne(where: query).get()
        }
        
        @discardableResult
        public func deleteOne<Query: MongoKittenQuery>(where query: Query) async throws -> DeleteReply {
            try await nio.deleteOne(where: query).get()
        }
        
        @discardableResult
        public func deleteAll(where query: Document) async throws -> DeleteReply {
            try await nio.deleteAll(where: query).get()
        }
        
        @discardableResult
        public func deleteAll<Query: MongoKittenQuery>(where query: Query) async throws -> DeleteReply {
            try await nio.deleteAll(where: query).get()
        }
        
        public func find(_ query: Document = [:]) -> FindQueryBuilder {
            nio.find(query)
        }
        
        public func find<Query: MongoKittenQuery>(_ query: Query) -> FindQueryBuilder {
            nio.find(query)
        }

        public func find<D: Decodable>(_ query: Document = [:], as type: D.Type) -> MappedCursor<FindQueryBuilder, D> {
            nio.find(query, as: type)
        }

        public func findOne<D: Decodable>(_ query: Document = [:], as type: D.Type) async throws -> D? {
            try await nio.findOne(query, as: type).get()
        }
        
        @discardableResult
        public func insert(_ document: Document) async throws -> InsertReply {
            try await nio.insert(document).get()
        }
        
        @discardableResult
        public func insertMany(_ documents: [Document]) async throws -> InsertReply {
            try await nio.insertMany(documents).get()
        }
        
        @discardableResult
        public func insertEncoded<E: Encodable>(_ document: E) async throws -> InsertReply {
            try await nio.insertEncoded(document).get()
        }
        
        @discardableResult
        public func insertManyEncoded<E: Encodable>(_ documents: [E]) async throws -> InsertReply {
            try await nio.insertManyEncoded(documents).get()
        }
        
        @discardableResult
        public func updateOne(
            where query: Document,
            to document: Document
        ) async throws -> UpdateReply {
            try await nio.updateOne(where: query, to: document).get()
        }
        
        @discardableResult
        public func updateEncoded<E: Encodable>(
            where query: Document,
            to model: E
        ) async throws -> UpdateReply {
            try await nio.updateEncoded(where: query, to: model).get()
        }
        
        @discardableResult
        public func updateOne<Query: MongoKittenQuery>(
            where query: Query,
            to document: Document
        ) async throws -> UpdateReply {
            try await nio.updateEncoded(where: query, to: document).get()
        }
        
        @discardableResult
        public func updateEncoded<Query: MongoKittenQuery, E: Encodable>(
            where query: Query,
            to model: E
        ) async throws -> UpdateReply {
            try await nio.updateEncoded(where: query, to: model).get()
        }
        
        @discardableResult
        public func updateMany(
            where query: Document,
            to document: Document
        ) async throws -> UpdateReply {
            try await nio.updateManyEncoded(where: query, to: document).get()
        }
        
        @discardableResult
        public func updateManyEncoded<E: Encodable>(
            where query: Document,
            to model: E
        ) async throws -> UpdateReply {
            try await nio.updateManyEncoded(where: query, to: model).get()
        }
        
        @discardableResult
        public func updateMany<Query: MongoKittenQuery>(
            where query: Query,
            to document: Document
        ) async throws -> UpdateReply {
            try await nio.updateMany(where: query, to: document).get()
        }
        
        @discardableResult
        public func updateManyEncoded<Query: MongoKittenQuery, E: Encodable>(
            where query: Query,
            to model: E
        ) async throws -> UpdateReply {
            try await nio.updateManyEncoded(where: query, to: model).get()
        }
        
        @discardableResult
        public func updateMany(
            where query: Document,
            setting: Document?,
            unsetting: Document?
        ) async throws -> UpdateReply {
            try await nio.updateMany(where: query, setting: setting, unsetting: unsetting).get()
        }
        
        @discardableResult
        public func upsert(_ document: Document, where query: Document) async throws -> UpdateReply {
            try await nio.upsert(document, where: query).get()
        }
        
        @discardableResult
        public func upsertEncoded<E: Encodable>(_ model: E, where query: Document) async throws -> UpdateReply {
            try await nio.upsertEncoded(model, where: query).get()
        }
        
        @discardableResult
        public func upsert<Query: MongoKittenQuery>(_ document: Document, where query: Query) async throws -> UpdateReply {
            try await nio.upsert(document, where: query).get()
        }
        
        @discardableResult
        public func upsertEncoded<Query: MongoKittenQuery, E: Encodable>(_ model: E, where query: Query) async throws -> UpdateReply {
            try await nio.upsertEncoded(model, where: query).get()
        }
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
