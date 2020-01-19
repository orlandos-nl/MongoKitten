import NIO
import Logging
import MongoCore

public struct MongoConnectionPoolRequest {
    public var writable: Bool

    public init(writable: Bool) {
        self.writable = writable
    }
}

public protocol MongoConnectionPool {
    func next(for request: MongoConnectionPoolRequest) -> EventLoopFuture<MongoConnection>
    var eventLoop: EventLoop { get }
    var wireVersion: WireVersion? { get }
    var sessionManager: MongoSessionManager { get }
    var logger: Logger { get }
}

extension MongoConnection: MongoConnectionPool {
    public func next(for request: MongoConnectionPoolRequest) -> EventLoopFuture<MongoConnection> {
        return eventLoop.makeSucceededFuture(self)
    }
    
    public var wireVersion: WireVersion? {
        return serverHandshake?.maxWireVersion
    }
}

public enum MongoConnectionState {
    /// Busy attempting to connect
    case connecting

    /// Connected with <connectionCount> active connections
    case connected(connectionCount: Int)

    /// No connections are open to MongoDB
    case disconnected

    /// The cluster has been shut down
    case closed
}
