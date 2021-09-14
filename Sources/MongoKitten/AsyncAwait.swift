#if compiler(>=5.5)
import _NIOConcurrency
import NIO
import MongoClient
import MongoKittenCore

@available(macOS 12, iOS 15, *)
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
        
        init(nio: MongoCluster) {
            self.nio = nio
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
    
    public var `async`: Async {
        Async(nio: self)
    }
}

@available(macOS 12, iOS 15, *)
extension MongoDatabase {
    public struct Async {
        public let nio: MongoDatabase
        
        init(nio: MongoDatabase) {
            self.nio = nio
        }
        
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
    
    public var `async`: Async {
        Async(nio: self)
    }
}

@available(macOS 12, iOS 15, *)
extension MongoCollection {
    public struct Async {
        public let nio: MongoCollection
        
        init(nio: MongoCollection) {
            self.nio = nio
        }
        
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
        
        public func watch(
            options: ChangeStreamOptions = .init()
        ) async throws -> ChangeStream<Document> {
            return try await nio.watch(options: options).get()
        }
        
        public func watch<T: Decodable>(
            options: ChangeStreamOptions = .init(),
            as type: T.Type,
            using decoder: BSONDecoder = BSONDecoder()
        ) async throws -> ChangeStream<T> {
            return try await nio.watch(options: options, as: type, using: decoder).get()
        }
        
        /// Modifies and returns a single document.
        /// - Parameters:
        ///   - query: The selection criteria for the modification.
        ///   - update: If passed a document with update operator expressions, performs the specified modification. If passed a replacement document performs a replacement.
        ///   - remove: Removes the document specified in the query field. Defaults to `false`
        ///   - returnValue: Wether to return the `original` or `modified` document.
        public func findAndModify(
            where query: Document,
            update document: Document = [:],
            remove: Bool = false,
            returnValue: FindAndModifyReturnValue = .original
        ) -> FindAndModifyBuilder.Async {
            nio.findAndModify(where: query, update: document, remove: remove, returnValue: returnValue).async
        }
        
        /// Deletes a single document based on the query, returning the deleted document.
        /// - Parameters:
        ///   - query: The selection criteria for the deletion.
        public func findOneAndDelete(
            where query: Document
        ) -> FindAndModifyBuilder.Async {
            nio.findOneAndDelete(where: query).async
        }
        
        /// Replaces a single document based on the specified query.
        /// - Parameters:
        ///   - query: The selection criteria for the upate.
        ///   - replacement: The replacement document.
        ///   - returnValue: Wether to return the `original` or `modified` document.
        public func findOneAndReplace(
            where query: Document,
            replacement document: Document,
            returnValue: FindAndModifyReturnValue = .original
        ) -> FindAndModifyBuilder.Async {
            nio.findOneAndReplace(where: query, replacement: document, returnValue: returnValue).async
        }
        
        /// Updates a single document based on the specified query.
        /// - Parameters:
        ///   - query: The selection criteria for the upate.
        ///   - document: The update document.
        ///   - returnValue: Wether to return the `original` or `modified` document.
        public func findOneAndUpdate(
            where query: Document,
            to document: Document,
            returnValue: FindAndModifyReturnValue = .original
        ) -> FindAndModifyBuilder.Async {
            nio.findOneAndUpdate(where: query, to: document, returnValue: returnValue).async
        }
        
        /// Modifies and returns a single document.
        /// - Parameters:
        ///   - query: The selection criteria for the modification.
        ///   - update: If passed a document with update operator expressions, performs the specified modification. If passed a replacement document performs a replacement.
        ///   - remove: Removes the document specified in the query field. Defaults to `false`
        ///   - returnValue: Wether to return the `original` or `modified` document.
        public func findAndModify<Query: MongoKittenQuery>(
            where query: Query,
            update document: Document = [:],
            remove: Bool = false,
            returnValue: FindAndModifyReturnValue = .original
        ) -> FindAndModifyBuilder.Async {
            nio.findAndModify(where: query, update: document, remove: remove, returnValue: returnValue).async
        }
        
        /// Deletes a single document based on the query, returning the deleted document.
        /// - Parameters:
        ///   - query: The selection criteria for the deletion.
        public func findOneAndDelete<Query: MongoKittenQuery>(
            where query: Query
        ) -> FindAndModifyBuilder.Async {
            nio.findOneAndDelete(where: query).async
        }
        
        /// Replaces a single document based on the specified query.
        /// - Parameters:
        ///   - query: The selection criteria for the upate.
        ///   - replacement: The replacement document.
        ///   - returnValue: Wether to return the `original` or `modified` document.
        public func findOneAndReplace<Query: MongoKittenQuery>(
            where query: Query,
            replacement document: Document,
            returnValue: FindAndModifyReturnValue = .original
        ) -> FindAndModifyBuilder.Async {
            nio.findOneAndReplace(where: query, replacement: document, returnValue: returnValue).async
        }
        
        /// Updates a single document based on the specified query.
        /// - Parameters:
        ///   - query: The selection criteria for the upate.
        ///   - document: The update document.
        ///   - returnValue: Wether to return the `original` or `modified` document.
        public func findOneAndUpdate<Query: MongoKittenQuery>(
            where query: Query,
            to document: Document,
            returnValue: FindAndModifyReturnValue = .original
        ) -> FindAndModifyBuilder.Async {
            nio.findOneAndUpdate(where: query, to: document, returnValue: returnValue).async
        }
    }
    
    public var `async`: Async {
        Async(nio: self)
    }
}

@available(macOS 12, iOS 15, *)
extension FindAndModifyBuilder {
    public struct Async {
        let nio: FindAndModifyBuilder
        
        public func execute() async throws -> FindAndModifyReply {
            try await nio.execute().get()
        }
        
        public func decode<D: Decodable>(_ type: D.Type) async throws -> D? {
            try await nio.decode(type).get()
        }
        
        public func sort(_ sort: Sort) -> FindAndModifyBuilder.Async {
            nio.sort(sort).async
        }
        
        public func sort(_ sort: Document) -> FindAndModifyBuilder.Async {
            nio.sort(sort).async
        }
        
        public func project(_ projection: Projection) -> FindAndModifyBuilder.Async {
            nio.project(projection).async
        }
        
        public func project(_ projection: Document) -> FindAndModifyBuilder.Async {
            nio.project(projection).async
        }
        
        public func writeConcern(_ concern: WriteConcern) -> FindAndModifyBuilder.Async {
            nio.writeConcern(concern).async
        }
        
        public func collation(_ collation: Collation) -> FindAndModifyBuilder.Async {
            nio.collation(collation).async
        }
    }
    
    public var async: Async {
        Async(nio: self)
    }
}

@available(macOS 12, iOS 15, *)
extension MappedCursor: AsyncSequence {
    public final class AsyncIterator: AsyncIteratorProtocol {
        fileprivate let cursor: MappedCursor<Base, Element>
        private var finalized: FinalizedCursor<MappedCursor<Base, Element>>?
        private var results = [Element]()
        
        fileprivate init(cursor: MappedCursor<Base, Element>) {
            self.cursor = cursor
        }
        
        public func next() async throws -> Element? {
            let cursor: FinalizedCursor<MappedCursor<Base, Element>>
            
            if let finalized = self.finalized {
                cursor = finalized
            } else {
                cursor = try await self.cursor.execute().get()
                self.finalized = cursor
            }
            
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

@available(macOS 12, iOS 15, *)
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

@available(macOS 12, iOS 15, *)
extension ChangeStream {
    public func awaitClose() async throws {
        try await cursor.awaitClose()
    }
}

@available(macOS 12, iOS 15, *)
extension FinalizedCursor {
    public func awaitClose() async throws {
        try await cursor.closeFuture.get()
    }
    
    public func nextBatch(batchSize: Int = 101, failable: Bool = false) async throws -> [Base.Element] {
        try await nextBatch(batchSize: batchSize, failable: failable).get()
    }
    
    public func close() async throws {
        try await close().get()
    }
}
#endif
