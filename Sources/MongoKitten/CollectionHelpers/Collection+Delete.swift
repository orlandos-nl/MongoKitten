import MongoCore
import NIO

extension MongoCollection {
    public func deleteOne(where query: Document, writeConcern: WriteConcern? = nil) -> EventLoopFuture<DeleteReply> {
        return pool.next(for: .writable).flatMap { connection in
            var command = DeleteCommand(where: query, limit: .one, fromCollection: self.name)
            command.writeConcern = writeConcern
            return connection.executeCodable(
                command,
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: self.sessionId ?? connection.implicitSessionId
            )
        }.decodeReply(DeleteReply.self)._mongoHop(to: hoppedEventLoop)
    }
    
    public func deleteAll(where query: Document, writeConcern: WriteConcern? = nil) -> EventLoopFuture<DeleteReply> {
        return pool.next(for: .writable).flatMap { connection in
            var command = DeleteCommand(where: query, limit: .all, fromCollection: self.name)
            command.writeConcern = writeConcern
            return connection.executeCodable(
                command,
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: self.sessionId ?? connection.implicitSessionId
            )
        }.decodeReply(DeleteReply.self)._mongoHop(to: hoppedEventLoop)
    }
    
    public func deleteOne<Q: MongoKittenQuery>(where filter: Q, writeConcern: WriteConcern? = nil) -> EventLoopFuture<DeleteReply> {
        return self.deleteOne(where: filter.makeDocument(), writeConcern: writeConcern)
    }
    
    public func deleteAll<Q: MongoKittenQuery>(where filter: Q, writeConcern: WriteConcern? = nil) -> EventLoopFuture<DeleteReply> {
        return self.deleteAll(where: filter.makeDocument(), writeConcern: writeConcern)
    }
}
