#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore
import NIO
import MongoClient
import MongoKitten

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension MeowDatabase {
    public struct Async {
        public let nio: MeowDatabase
        
        public var raw: MongoDatabase.Async {
            nio.raw.async
        }
        
        init(nio: MeowDatabase) {
            self.nio = nio
        }
        
        public var name: String { nio.raw.name }
        
        public func collection<M: BaseModel>(for model: M.Type) -> MeowCollection<M>.Async {
            return MeowCollection<M>(database: nio, named: M.collectionName).async
        }
        
        public subscript<M: BaseModel>(type: M.Type) -> MeowCollection<M>.Async {
            return collection(for: type)
        }
    }
    
    public var `async`: Async {
        Async(nio: self)
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension MeowCollection {
    public struct Async {
        public let nio: MeowCollection<M>
        
        init(nio: MeowCollection<M>) {
            self.nio = nio
        }
        
        public var raw: MongoCollection.Async {
            nio.raw.async
        }
    }
    
    public var `async`: Async {
        Async(nio: self)
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension MeowCollection.Async where M: ReadableModel {
    public func find(where filter: Document = [:]) -> MappedCursor<FindQueryBuilder, M> {
        return nio.find(where: filter)
    }
    
    public func find<Q: MongoKittenQuery>(where filter: Q) -> MappedCursor<FindQueryBuilder, M> {
        return self.find(where: filter.makeDocument())
    }
    
    public func findOne(where filter: Document) async throws -> M? {
        return try await nio.findOne(where: filter).get()
    }
    
    public func findOne<Q: MongoKittenQuery>(where filter: Q) async throws -> M? {
        return try await nio.findOne(where: filter).get()
    }
    
    public func count(where filter: Document) async throws -> Int {
        return try await nio.count(where: filter).get()
    }
    
    public func count<Q: MongoKittenQuery>(where filter: Q) async throws -> Int {
        return try await self.count(where: filter.makeDocument())
    }
    
    public func watch(options: ChangeStreamOptions = .init()) async throws -> ChangeStream<M> {
        return try await nio.watch(options: options).get()
    }
    
    public func buildChangeStream(options: ChangeStreamOptions = .init(), @AggregateBuilder build: () -> AggregateBuilderStage) async throws -> ChangeStream<M> {
        return try await nio.buildChangeStream(options: options, build: build).get()
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension MutableModel {
    @discardableResult
    public func save(in database: MeowDatabase.Async) async throws -> MeowOperationResult {
        try await self.save(in: database.nio).get()
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension MeowCollection.Async where M: MutableModel {
    @discardableResult
    public func insert(_ instance: M) async throws -> InsertReply {
        return try await nio.insert(instance).get()
    }
    
    @discardableResult
    public func insertMany(_ instances: [M]) async throws -> InsertReply {
        return try await nio.insertMany(instances).get()
    }
    
    @discardableResult
    public func upsert(_ instance: M) async throws -> UpdateReply {
        return try await nio.upsert(instance).get()
    }
    
    @discardableResult
    public func deleteOne(where filter: Document) async throws -> DeleteReply {
        return try await nio.deleteOne(where: filter).get()
    }
    
    @discardableResult
    public func deleteOne<Q: MongoKittenQuery>(where filter: Q) async throws -> DeleteReply {
        return try await nio.deleteOne(where: filter).get()
    }
    
    @discardableResult
    public func deleteAll(where filter: Document) async throws -> DeleteReply {
        return try await nio.deleteAll(where: filter).get()
    }
    
    @discardableResult
    public func deleteAll<Q: MongoKittenQuery>(where filter: Q) async throws -> DeleteReply {
        return try await nio.deleteAll(where: filter).get()
    }
    
    //    public func saveChanges(_ changes: PartialChange<M>) -> EventLoopFuture<UpdateReply> {
    //        return raw.updateOne(where: "_id" == changes.entity, to: [
    //            "$set": changes.changedFields,
    //            "$unset": changes.removedFields
    //        ])
    //    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Reference {
    /// Resolves a reference
    public func resolve(in db: MeowDatabase.Async, where query: Document = Document()) async throws -> M {
        try await resolve(in: db.nio, where: query).get()
    }
    
    /// Resolves a reference, returning `nil` if the referenced object cannot be found
    public func resolveIfPresent(in db: MeowDatabase.Async, where query: Document = Document()) async throws -> M? {
        try await resolveIfPresent(in: db.nio, where: query).get()
    }
    
    public func exists(in db: MeowDatabase.Async) async throws -> Bool {
        return try await exists(in: db.nio).get()
    }
    
    public func exists(in db: MeowDatabase.Async, where filter: Document) async throws -> Bool {
        return try await exists(in: db.nio, where: filter).get()
    }
    
    public func exists<Query: MongoKittenQuery>(in db: MeowDatabase.Async, where filter: Query) async throws -> Bool {
        return try await exists(in: db.nio, where: filter).get()
    }
}
    
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Reference where M: MutableModel {
    @discardableResult
    public func deleteTarget(in context: MeowDatabase) async throws -> MeowOperationResult {
        try await deleteTarget(in: context).get()
    }
}
#endif
