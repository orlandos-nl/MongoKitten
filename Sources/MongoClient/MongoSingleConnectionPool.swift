import NIO
import Logging
import MongoCore

/// A connection pool that only ever uses a single connection. Recreates the connection when it's closed using the provided `buildConnection` closure.
public final actor MongoSingleConnectionPool: MongoConnectionPool {
    public typealias BuildConnection = @Sendable () async throws -> MongoConnection
    
    public var wireVersion: WireVersion? {
        get async {
            await connection?.wireVersion
        }
    }

    public let sessionManager = MongoSessionManager()
    public let logger = Logger(label: "org.orlandos-nl.mongokitten.single-connection-pool")
    
    let buildConnection: BuildConnection
    let authenticationSource: String
    let credentials: ConnectionSettings.Authentication
    var connection: MongoConnection?
    
    /// Creates a new `MongoSingleConnectionPool` that will use the provided `buildConnection` closure to create a new connection when needed.
    /// - parameter authenticationSource: The database to authenticate to
    /// - parameter credentials: The credentials to use for authentication
    /// - parameter buildConnection: The closure that will be used to create a new connection when needed
    public init(
        authenticationSource: String = "admin",
        credentials: ConnectionSettings.Authentication = .unauthenticated,
        buildConnection: @escaping BuildConnection
    ) {
        self.authenticationSource = authenticationSource
        self.credentials = credentials
        self.buildConnection = buildConnection
    }
    
    /// Creates a new `MongoSingleConnectionPool` that will use the provided `buildConnection` closure to create a new connection when needed. The connection will be authenticated using the provided credentials.
    public func next(for request: ConnectionPoolRequest) async throws -> MongoConnection {
        if let connection = connection, connection.channel.isActive {
            return connection
        }
        
        let connection = try await buildConnection()
        try await connection.authenticate(
            clientDetails: nil,
            using: self.credentials,
            to: self.authenticationSource
        )
        
        self.connection = connection
        
        return connection
    }
}
