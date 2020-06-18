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
        }.decodeReply(DeleteReply.self)._mongoHop(to: hoppedEventLoop)
    }
    
    public func deleteAll(where query: Document) -> EventLoopFuture<DeleteReply> {
        return pool.next(for: .writable).flatMap { connection in
            return connection.executeCodable(
                DeleteCommand(where: query, limit: .all, fromCollection: self.name),
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: connection.implicitSessionId
            )
        }.decodeReply(DeleteReply.self)._mongoHop(to: hoppedEventLoop)
    }
    
    public func deleteOne<Q: MongoKittenQuery>(where filter: Q) -> EventLoopFuture<DeleteReply> {
        return self.deleteOne(where: filter.makeDocument())
    }
    
    public func deleteAll<Q: MongoKittenQuery>(where filter: Q) -> EventLoopFuture<DeleteReply> {
        return self.deleteAll(where: filter.makeDocument())
    }
    
    /// Performs a delete operation with the given delete statements
    /// - Parameter removals: A collection of one or more delete statements to perform.
    public func deleteAll(_ removals: [DeleteCommand.Removal]) -> EventLoopFuture<DeleteReply> {
        return pool.next(for: .writable).flatMap { connection in
            return connection.executeCodable(
                DeleteCommand(removals, fromCollection: self.name),
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: connection.implicitSessionId
            )
        }.decodeReply(DeleteReply.self)._mongoHop(to: hoppedEventLoop)
    }
    
    /// Performs a delete operation with the given delete statement.
    /// - Parameter removal: A delete statement to perform.
    public func deleteOne(_ removal: DeleteCommand.Removal) -> EventLoopFuture<DeleteReply> {
        return self.deleteAll([removal])
    }
}
