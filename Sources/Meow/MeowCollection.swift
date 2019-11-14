import MongoKitten
import MongoCore
import NIO

public struct MeowCollection<M: _Model> {
    public let database: MeowDatabase
    public let name: String
    public var raw: MongoCollection { return database.raw[name] }
    public var eventLoop: EventLoop { return database.eventLoop }
    
    public init(database: MeowDatabase, named name: String) {
        self.database = database
        self.name = name
    }
    
    public func insert(_ instance: M) -> EventLoopFuture<InsertReply> {
        do {
            let document = try instance.encode(to: Document.self)
            return raw.insert(document)
        } catch {
            return database.eventLoop.makeFailedFuture(error)
        }
    }
    
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
    
    public func upsert(_ instance: M) -> EventLoopFuture<UpdateReply> {
        do {
            let document = try instance.encode(to: Document.self)
            return raw.upsert(document, where: "_id" == instance._id)
        } catch {
            return database.eventLoop.makeFailedFuture(error)
        }
    }
    
    //    public func saveChanges(_ changes: PartialChange<M>) -> EventLoopFuture<UpdateReply> {
    //        return raw.updateOne(where: "_id" == changes.entity, to: [
    //            "$set": changes.changedFields,
    //            "$unset": changes.removedFields
    //        ])
    //    }
    
    public func watch() -> EventLoopFuture<ChangeStream<M>> {
        return raw.watch(as: M.self, using: M.decoder)
    }
}
