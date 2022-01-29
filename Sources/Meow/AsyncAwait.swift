#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore
import NIO
import MongoClient
import MongoKitten

@available(macOS 10.15, iOS 13, watchOS 8, tvOS 15, *)
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

@available(macOS 10.15, iOS 13, watchOS 8, tvOS 15, *)
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

@available(macOS 10.15, iOS 13, watchOS 8, tvOS 15, *)
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

@available(macOS 10.15, iOS 13, watchOS 8, tvOS 15, *)
extension MutableModel {
    @discardableResult
    public func save(in database: MeowDatabase.Async) async throws -> MeowOperationResult {
        try await self.save(in: database.nio).get()
    }
}

@available(macOS 10.15, iOS 13, watchOS 8, tvOS 15, *)
extension MeowCollection.Async where M: MutableModel {
    @discardableResult
    public func insert(_ instance: M, writeConcern: WriteConcern? = nil) async throws -> InsertReply {
        return try await nio.insert(instance, writeConcern: writeConcern).get()
    }
    
    @discardableResult
    public func insertMany(_ instances: [M], writeConcern: WriteConcern? = nil) async throws -> InsertReply {
        return try await nio.insertMany(instances, writeConcern: writeConcern).get()
    }
    
    @discardableResult
    public func upsert(_ instance: M) async throws -> UpdateReply {
        return try await nio.upsert(instance).get()
    }
    
    @discardableResult
    public func deleteOne(where filter: Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await nio.deleteOne(where: filter, writeConcern: writeConcern).get()
    }
    
    @discardableResult
    public func deleteOne<Q: MongoKittenQuery>(where filter: Q, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await nio.deleteOne(where: filter, writeConcern: writeConcern).get()
    }
    
    @discardableResult
    public func deleteAll(where filter: Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await nio.deleteAll(where: filter, writeConcern: writeConcern).get()
    }
    
    @discardableResult
    public func deleteAll<Q: MongoKittenQuery>(where filter: Q, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await nio.deleteAll(where: filter, writeConcern: writeConcern).get()
    }
    
    //    public func saveChanges(_ changes: PartialChange<M>) -> EventLoopFuture<UpdateReply> {
    //        return raw.updateOne(where: "_id" == changes.entity, to: [
    //            "$set": changes.changedFields,
    //            "$unset": changes.removedFields
    //        ])
    //    }
}

@available(macOS 10.15, iOS 13, watchOS 8, tvOS 15, *)
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
    
@available(macOS 10.15, iOS 13, watchOS 8, tvOS 15, *)
extension Reference where M: MutableModel {
    @discardableResult
    public func deleteTarget(in context: MeowDatabase) async throws -> MeowOperationResult {
        try await deleteTarget(in: context).get()
    }
}

@available(macOS 10.15, iOS 13, watchOS 8, tvOS 15, *)
extension MeowDatabase.Async {
    /// Runs a migration closure that is not tied to a certain model
    /// The closure will be executed only once, because the migration is registered in the MeowMigrations collection
    public func migrateCustom(
        _ description: String,
        migration: @escaping () throws -> EventLoopFuture<Void>
    ) async throws {
        try await nio.migrateCustom(description, migration: migration).get()
    }
    
    public func migrate<M: Model>(_ description: String, on model: M.Type, migration: @escaping (Migrator<M>) throws -> Void) async throws {
        try await nio.migrate(description, on: model, migration: migration).get()
    }
}

@available(macOS 10.15, iOS 13, watchOS 8, tvOS 15, *)
extension Migrator {
    public func addAsync(_ action: @escaping (MeowCollection<M>.Async) async throws -> ()) {
        add { collection in
            let promise = collection.eventLoop.makePromise(of: Void.self)
            promise.completeWithTask {
                try await action(collection.async)
            }
            return promise.futureResult
        }
    }
    
    func execute() async throws {
        try await execute().get()
    }
}
#endif
