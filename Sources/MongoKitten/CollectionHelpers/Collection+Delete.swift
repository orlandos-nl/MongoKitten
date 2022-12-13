import MongoCore
import NIO

extension MongoCollection {
    /// Deletes the first document matching the given query. If no query is given, it deletes the first document in the collection.
    /// - Parameter query: The query to match documents against
    /// - Parameter writeConcern: The write concern to use for this operation
    /// - Returns: The amount of documents deleted
    @discardableResult
    public func deleteOne(where query: Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        let connection = try await pool.next(for: .writable)
        var command = DeleteCommand(where: query, limit: .one, fromCollection: self.name)
        command.writeConcern = writeConcern
        return try await connection.executeCodable(
            command,
            decodeAs: DeleteReply.self,
            namespace: self.database.commandNamespace,
            in: self.transaction,
            sessionId: self.sessionId ?? connection.implicitSessionId
        )
    }
    
    /// Deletes all documents matching the given query. If no query is given, it deletes all documents in the collection.
    /// - Parameter query: The query to match documents against
    /// - Parameter writeConcern: The write concern to use for this operation
    /// - Returns: The amount of documents deleted
    @discardableResult
    public func deleteAll(where query: Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        let connection = try await pool.next(for: .writable)
        var command = DeleteCommand(where: query, limit: .all, fromCollection: self.name)
        command.writeConcern = writeConcern
        return try await connection.executeCodable(
            command,
            decodeAs: DeleteReply.self,
            namespace: self.database.commandNamespace,
            in: self.transaction,
            sessionId: self.sessionId ?? connection.implicitSessionId
        )
    }
    
    /// Deletes the first document matching the given query.
    /// - Parameter query: The query to match documents against
    /// - Parameter writeConcern: The write concern to use for this operation
    /// - Returns: The amount of documents deleted
    @discardableResult
    public func deleteOne<Q: MongoKittenQuery>(where filter: Q, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await deleteOne(where: filter.makeDocument(), writeConcern: writeConcern)
    }
    
    /// Deletes all documents matching the given query.
    /// - Parameter query: The query to match documents against
    /// - Parameter writeConcern: The write concern to use for this operation
    /// - Returns: The amount of documents deleted
    @discardableResult
    public func deleteAll<Q: MongoKittenQuery>(where filter: Q, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await deleteAll(where: filter.makeDocument(), writeConcern: writeConcern)
    }
}
