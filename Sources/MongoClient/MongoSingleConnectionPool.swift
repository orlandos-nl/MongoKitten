import NIO
import Logging
import MongoCore

public final actor MongoSingleConnectionPool: MongoConnectionPool {
    public typealias BuildConnection = @Sendable () async throws -> MongoConnection
    
    public var wireVersion: WireVersion? {
        get async {
            await connection?.wireVersion
        }
    }
    public let sessionManager = MongoSessionManager()
    public let logger = Logger(label: "org.openkitten.mongokitten.single-connection-pool")
    
    let buildConnection: BuildConnection
    let authenticationSource: String
    let credentials: ConnectionSettings.Authentication
    var connection: MongoConnection?
    
    public init(
        authenticationSource: String = "admin",
        credentials: ConnectionSettings.Authentication = .unauthenticated,
        buildConnection: @escaping BuildConnection
    ) {
        self.authenticationSource = authenticationSource
        self.credentials = credentials
        self.buildConnection = buildConnection
    }
    
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
