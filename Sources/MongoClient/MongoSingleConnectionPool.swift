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
        
        let connection = try await self.buildConnection()
        // we must inline ``MongoConnection.authenticate(clientDetails:using:to:)`` 
        // due to the llvm coroutine splitting issue `https://github.com/apple/swift/issues/60380`. 
        // 
        // this could also be accomplished by adding `@inline(never)` to 
        // ``MongoConnection.authenticate(clientDetails:using:to:)``, but this 
        // preserves the runtime behavior more closely.
        let handshake = try await connection.doHandshake(
            clientDetails: nil,
            credentials: self.credentials,
            authenticationDatabase: self.authenticationSource
        )
        
        await connection.context.setServerHandshake(to: handshake)
        try await connection.authenticate(to: self.authenticationSource, 
            serverHandshake: handshake, 
            with: self.credentials)
        
        self.connection = connection
        
        return connection
    }
}
