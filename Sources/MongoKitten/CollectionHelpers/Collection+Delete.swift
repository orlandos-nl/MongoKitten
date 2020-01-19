import MongoCore
import NIO

extension MongoCollection {
    public func deleteOne(where query: Document) -> EventLoopFuture<DeleteReply> {
        return pool.next(for: .writable).flatMap { connection in
            return connection.executeCodable(
                DeleteCommand(where: query, limit: .one, fromCollection: self.name),
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: self.sessionId ?? connection.implicitSessionId
            )
        }.decode(DeleteReply.self)._mongoHop(to: hoppedEventLoop)
    }
    
    public func deleteAll(where query: Document) -> EventLoopFuture<DeleteReply> {
        return pool.next(for: .writable).flatMap { connection in
            return connection.executeCodable(
                DeleteCommand(where: query, limit: .all, fromCollection: self.name),
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: connection.implicitSessionId
            )
        }.decode(DeleteReply.self)._mongoHop(to: hoppedEventLoop)
    }
}
