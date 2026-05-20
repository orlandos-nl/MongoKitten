import MongoClient

extension MongoDatabase {
    /// Checks MongoDB connectivity using the `ping` command.
    ///
    /// Executes the [`ping`](https://www.mongodb.com/docs/manual/reference/command/ping/)
    /// command and verifies that the server responds with `ok: 1`.
    ///
    /// - Returns: `"ok"` if the database responds successfully.
    /// - Throws: An error if the command execution or decoding fails.
    public func checkConnection() async throws {
        struct Request: Codable, Sendable {
            let ping: Int
        }
        struct Response: Decodable, Sendable {
            let ok: Double
        }
        let request = Request(ping: 1)
        let namespace = MongoNamespace(to: "$cmd", inDatabase: self.name)
        let connection = try await pool.next(for: .basic)
        let response = try await connection.executeCodable(
            request,
            decodeAs: Response.self,
            namespace: namespace,
            sessionId: nil,
            logMetadata: logMetadata,
            traceLabel: "Ping<\(namespace)>",
            serviceContext: nil
        )
        guard response.ok == 1 else {
            throw MongoError(.cannotConnect, reason: .connectionClosed)
        }
    }
}
