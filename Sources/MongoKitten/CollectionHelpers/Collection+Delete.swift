import MongoCore
import NIO

extension MongoCollection {
    public func deleteOne(where query: Document) -> EventLoopFuture<DeleteReply> {
        return pool.next(for: .writable).flatMap { connection in
            return connection.executeCodable(
                DeleteCommand(where: query, limit: .one, fromCollection: self.name),
                namespace: self.database.commandNamespace
            )
        }.decode(DeleteReply.self)
    }
    
    public func deleteAll(where query: Document) -> EventLoopFuture<DeleteReply> {
        return pool.next(for: .writable).flatMap { connection in
            return connection.executeCodable(
                DeleteCommand(where: query, limit: .all, fromCollection: self.name),
                namespace: self.database.commandNamespace
            )
        }.decode(DeleteReply.self)
    }
}
