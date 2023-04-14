import MongoCore
import NIO

extension MongoCollection {
    /// Counts the amount of documents in this collection matching the given query. If no query is given, it counts all documents in the collection.
    /// - Parameter query: The query to match documents against
    /// - Returns: The amount of documents matching the query
    public func count(_ query: Document? = nil) async throws -> Int {
        guard transaction == nil else {
            throw MongoKittenError(.unsupportedFeatureByServer, reason: .transactionForUnsupportedQuery)
        }
        
        let connection = try await pool.next(for: .basic)
        return try await connection.executeCodable(
            CountCommand(on: self.name, where: query),
            decodeAs: CountReply.self,
            namespace: self.database.commandNamespace,
            in: self.transaction,
            sessionId: self.sessionId ?? connection.implicitSessionId,
            logMetadata: database.logMetadata,
            traceLabel: "Count<\(namespace)>",
            baggage: baggage
        ).count
    }

    /// Counts the amount of documents in this collection matching the given query. If no query is given, it counts all documents in the collection.
    /// - Parameter query: The query to match documents against
    /// - Returns: The amount of documents matching the query
    public func count<Query: MongoKittenQuery>(_ query: Query? = nil) async throws -> Int {
        return try await count(query?.makeDocument())
    }
}
