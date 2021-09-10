#if compiler(>=5.5)
import _NIOConcurrency
import NIO
import MongoClient
import MongoKitten

@available(macOS 12, iOS 15, *)
extension MeowDatabase {
    public struct Async {
        public let nio: MeowDatabase
        
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

@available(macOS 12, iOS 15, *)
extension MeowCollection {
    public struct Async {
        public let nio: MeowCollection<M>
        
        init(nio: MeowCollection<M>) {
            self.nio = nio
        }
    }
    
    public var `async`: Async {
        Async(nio: self)
    }
}

@available(macOS 12, iOS 15, *)
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
#endif
