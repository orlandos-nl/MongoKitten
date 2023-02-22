import MongoCore
import NIO

extension MongoCollection {
    /// Returns the distinct values for the given key in this collection matching the given query.
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
