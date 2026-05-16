import MongoClient

extension MongoDatabase {
    /// Returns current connection statistics from the MongoDB server.
    ///
    /// Executes the [`serverStatus`](https://www.mongodb.com/docs/manual/reference/command/serverStatus/)
    /// command and extracts the `connections` subdocument.
    ///
    /// - Returns: A `ConnectionStats` structure with current connection metrics.
    /// - Throws: An error if the command execution or decoding fails.
    public func getConnectionStats() async throws -> ConnectionStats {
        struct Request: Codable, Sendable {
            let serverStatus: Int
        }

        /// Intermediate wrapper to pluck only the `connections` field
        /// from the larger `serverStatus` response document.
        struct ServerStatusResponse: Decodable, Sendable {
            let connections: ConnectionStats
        }

        let request = Request(serverStatus: 1)
        let namespace = MongoNamespace(to: "$cmd", inDatabase: self.name)

        let connection = try await pool.next(for: .basic)
        let response = try await connection.executeCodable(
            request,
            decodeAs: ServerStatusResponse.self,
            namespace: namespace,
            sessionId: nil,
            logMetadata: logMetadata,
            traceLabel: "ServerStatus<\(namespace)>",
            serviceContext: nil
        )
        return response.connections
    }
}

// MARK: - ConnectionStats

/// Connection statistics returned by `db.serverStatus().connections`.
///
/// Reflects the current state of incoming client connections to the mongod/mongos instance.
public struct ConnectionStats: Decodable, Sendable {
    /// Number of incoming connections from clients currently open.
    public let current: Int
    /// Number of unused incoming connections available.
    /// Consider raising the system's `ulimit` if this approaches zero.
    public let available: Int
    /// Total number of incoming connections created since the process started.
    public let totalCreated: Int
    /// Number of incoming connections rejected because
    /// `net.maxIncomingConnections` was exceeded.
    public let rejected: Int
    /// Connections currently performing an active operation (not idle).
    public let active: Int
    /// Number of incoming connections handled by a dedicated thread
    /// (as opposed to using an async / borrowed thread model).
    public let threaded: Int
    /// Number of connections waiting to be established.
    public let queuedForEstablishment: Int64
    /// Number of connections using the legacy `isMaster` exhaust protocol.
    public let exhaustIsMaster: Int64
    /// Number of connections using the `hello` exhaust protocol.
    public let exhaustHello: Int64
    /// Number of connections currently awaiting a topology-change notification.
    public let awaitingTopologyChanges: Int64
    /// Number of load-balanced connections.
    public let loadBalanced: Int64
    /// Breakdown of connections rejected (or exempted) by the
    /// establishment-rate limiter.
    public let establishmentRateLimit: EstablishmentRateLimit
}

// MARK: - EstablishmentRateLimit

/// Rate-limiter counters nested inside `ConnectionStats`.
public struct EstablishmentRateLimit: Decodable, Sendable {
    /// Connections rejected by the rate limiter.
    public let rejected: Int64
    /// Connections exempted from the rate limiter.
    public let exempted: Int64
    /// Connections that were interrupted because the client disconnected
    /// while waiting for establishment.
    public let interruptedDueToClientDisconnect: Int64
}
