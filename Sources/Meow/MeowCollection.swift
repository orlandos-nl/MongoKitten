import MongoKitten
import MongoCore
import NIO

public struct MeowCollection<M: BaseModel> {
    public let database: MeowDatabase
    public let name: String
    public let raw: MongoCollection
    
    public init(database: MeowDatabase, named name: String) {
        self.database = database
        self.raw = database.raw[name]
        self.name = name
    }
}

extension MeowCollection where M: ReadableModel {
    public func find(where filter: Document = [:]) -> MappedCursor<FindQueryBuilder, M> {
        return raw.find(filter).decode(M.self)
    }
    
    public func find<Q: MongoKittenQuery>(where filter: Q) -> MappedCursor<FindQueryBuilder, M> {
        return self.find(where: filter.makeDocument())
    }
    
    public func findOne(where filter: Document) async throws -> M? {
        return try await raw.findOne(filter, as: M.self)
    }
    
    public func findOne<Q: MongoKittenQuery>(where filter: Q) async throws -> M? {
        return try await raw.findOne(filter, as: M.self)
    }
    
    public func count(where filter: Document) async throws -> Int {
        return try await raw.count(filter)
    }
    
    public func count<Q: MongoKittenQuery>(where filter: Q) async throws -> Int {
        return try await self.count(where: filter.makeDocument())
    }
    
    public func watch(options: ChangeStreamOptions = .init()) async throws -> ChangeStream<M> {
        return try await raw.watch(options: options, type: M.self, using: M.decoder)
    }
    
    public func buildChangeStream(options: ChangeStreamOptions = .init(), @AggregateBuilder build: () -> [AggregateBuilderStage]) async throws -> ChangeStream<M> {
        return try await raw.buildChangeStream(options: options, ofType: M.self, using: M.decoder, build: build)
    }
}

extension MeowCollection where M: MutableModel {
    @discardableResult
    public func insert(_ instance: M, writeConcern: WriteConcern? = nil) async throws -> InsertReply {
        return try await raw.insertEncoded(instance, writeConcern: writeConcern)
    }
    
    @discardableResult
    public func insertMany(_ instances: [M], writeConcern: WriteConcern? = nil) async throws -> InsertReply {
        return try await raw.insertManyEncoded(instances, writeConcern: writeConcern)
    }
    
    @discardableResult
    public func upsert(_ instance: M) async throws -> UpdateReply {
        let _id = try instance._id.encodePrimitive()
        return try await raw.upsertEncoded(instance, where: "_id" == _id)
    }
    
    @discardableResult
    public func deleteOne(where filter: Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await raw.deleteOne(where: filter, writeConcern: writeConcern)
    }
    
    @discardableResult
    public func deleteOne<Q: MongoKittenQuery>(where filter: Q, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await self.deleteOne(where: filter.makeDocument(), writeConcern: writeConcern)
    }
    
    @discardableResult
    public func deleteAll(where filter: Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await raw.deleteAll(where: filter, writeConcern: writeConcern)
    }
    
    @discardableResult
    public func deleteAll<Q: MongoKittenQuery>(where filter: Q, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await self.deleteAll(where: filter.makeDocument(), writeConcern: writeConcern)
    }
    
    //    public func saveChanges(_ changes: PartialChange<M>) -> EventLoopFuture<UpdateReply> {
    //        return raw.updateOne(where: "_id" == changes.entity, to: [
    //            "$set": changes.changedFields,
    //            "$unset": changes.removedFields
    //        ])
    //    }
}
