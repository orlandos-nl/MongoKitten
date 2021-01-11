import MongoKitten
import MongoCore
import NIO

public struct MeowCollection<M: BaseModel> {
    public let database: MeowDatabase
    public let name: String
    public let raw: MongoCollection
    public var eventLoop: EventLoop { return database.eventLoop }
    
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
    
    public func findOne(where filter: Document) -> EventLoopFuture<M?> {
        return raw.findOne(filter, as: M.self)
    }
    
    public func findOne<Q: MongoKittenQuery>(where filter: Q) -> EventLoopFuture<M?> {
        return raw.findOne(filter, as: M.self)
    }
    
    public func count(where filter: Document) -> EventLoopFuture<Int> {
        return raw.count(filter)
    }
    
    public func count<Q: MongoKittenQuery>(where filter: Q) -> EventLoopFuture<Int> {
        return self.count(where: filter.makeDocument())
    }
    
    public func watch() -> EventLoopFuture<ChangeStream<M>> {
        return raw.watch(as: M.self, using: M.decoder)
    }
    
    public func buildChangeStream(@AggregateBuilder build: () -> AggregateBuilderStage) -> EventLoopFuture<ChangeStream<M>> {
        return raw.buildChangeStream(as: M.self, build: build)
    }
}

extension MeowCollection where M: MutableModel {
    public func insert(_ instance: M) -> EventLoopFuture<InsertReply> {
        return raw.insertEncoded(instance)
    }
    
    public func insertMany(_ instances: [M]) -> EventLoopFuture<InsertReply> {
        return raw.insertManyEncoded(instances)
    }
    
    public func upsert(_ instance: M) -> EventLoopFuture<UpdateReply> {
        return raw.upsertEncoded(instance, where: "_id" == instance._id)
    }
    
    public func deleteOne(where filter: Document) -> EventLoopFuture<DeleteReply> {
        return raw.deleteOne(where: filter)
    }
    
    public func deleteOne<Q: MongoKittenQuery>(where filter: Q) -> EventLoopFuture<DeleteReply> {
        return self.deleteOne(where: filter.makeDocument())
    }
    
    public func deleteAll(where filter: Document) -> EventLoopFuture<DeleteReply> {
        return raw.deleteAll(where: filter)
    }
    
    public func deleteAll<Q: MongoKittenQuery>(where filter: Q) -> EventLoopFuture<DeleteReply> {
        return self.deleteAll(where: filter.makeDocument())
    }
    
    //    public func saveChanges(_ changes: PartialChange<M>) -> EventLoopFuture<UpdateReply> {
    //        return raw.updateOne(where: "_id" == changes.entity, to: [
    //            "$set": changes.changedFields,
    //            "$unset": changes.removedFields
    //        ])
    //    }
}
