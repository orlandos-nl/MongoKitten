import MongoCore
import NIO

extension MongoCollection {
    /// Counts the amount of documents in this collection matching the given query. If no query is given, this counts all documents in the collection.
    /// - Parameter query: The filter to match documents against before counting results
    /// - Returns: The amount of documents matching the query
    ///
    /// You can provide a filter, narrowing down which users to count
    ///
    /// ```swift
    /// let users: MongoCollection
    /// let usersRegistered = try await users.count()
    /// let usersActivated = try await users.count([
    ///   "activated": true
    /// ])
    /// ```
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
            serviceContext: context
        ).count
    }

    /// Counts the amount of documents in this collection matching the given query. If no query is given, this counts all documents in the collection.
    /// - Parameter query: The filter to match documents against
    /// - Returns: The amount of documents matching the query
    ///
    /// You can provide a filter, narrowing down which users to count
    ///
    /// ```swift
    /// let users: MongoCollection
    /// let usersRegistered = try await users.count()
    /// let usersActivated = try await users.count(""activated" == true")
    /// ```
    public func count<Query: MongoKittenQuery>(_ query: Query? = nil) async throws -> Int {
        return try await count(query?.makeDocument())
    }
}
