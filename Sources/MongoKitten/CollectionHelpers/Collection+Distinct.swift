import MongoCore
import NIO

extension MongoCollection {
    /// Returns the distinct values for the given key in this collection matching the given query.
    /// - Parameter key: The key to return the distinct values for
    /// - Parameter query: The query to match documents against, before returning the distinct values
    /// - Returns: The distinct values for the given key
    public func distinctValues(forKey key: String, where query: Document? = nil) async throws -> [Primitive] {
        let connection = try await pool.next(for: .basic)
        return try await connection.executeCodable(
            DistinctCommand(onKey: key, where: query, inCollection: self.name),
            decodeAs: DistinctReply.self,
            namespace: self.database.commandNamespace,
            in: self.transaction,
            sessionId: self.sessionId ?? connection.implicitSessionId,
            logMetadata: database.logMetadata
        ).distinctValues
    }
}
