import NIO
import Logging
import MongoCore

public final class MongoSingleConnectionPool: MongoConnectionPool {
    public private(set) var wireVersion: WireVersion?
    public let sessionManager = MongoSessionManager()
    public var logger: Logger = .defaultMongoCore
    
    let buildConnection: (EventLoop) -> EventLoopFuture<MongoConnection>
    public let eventLoop: EventLoop
    let authenticationSource: String
    let credentials: ConnectionSettings.Authentication
    var connection: EventLoopFuture<MongoConnection>?
    
    public init(
        eventLoop: EventLoop,
        authenticationSource: String = "admin",
        credentials: ConnectionSettings.Authentication = .unauthenticated,
        buildConnection: @escaping (EventLoop) -> EventLoopFuture<MongoConnection>
    ) {
        self.eventLoop = eventLoop
        self.authenticationSource = authenticationSource
        self.credentials = credentials
        self.buildConnection = buildConnection
    }
    
    public func next(for request: MongoConnectionPoolRequest) -> EventLoopFuture<MongoConnection> {
        if let connection = connection {
            return connection
        }
        
        let connection = buildConnection(eventLoop).flatMap { connection -> EventLoopFuture<MongoConnection> in
            return connection.authenticate(
                clientDetails: nil,
                using: self.credentials,
                to: self.authenticationSource
            ).map { connection }
        }
        
        self.connection = connection
        connection.whenFailure { [weak self] error in
            self?.connection = nil
        }
        connection.flatMap { connection in
            connection.closeFuture
        }.whenComplete { _ in
            self.connection = nil
        }
        
        return connection
    }
}
