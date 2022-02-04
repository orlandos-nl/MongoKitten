import NIO
import Logging
import MongoCore

public enum ConnectionPoolRequirement: Hashable, Sendable {
    case writable, new
}

public struct ConnectionPoolRequest: Sendable, ExpressibleByArrayLiteral {
    public let requirements: Set<ConnectionPoolRequirement>
    
    public init(arrayLiteral requirements: ConnectionPoolRequirement...) {
        self.requirements = Set(requirements)
    }
    
    public static let writable: ConnectionPoolRequest = [.writable]
    public static let basic: ConnectionPoolRequest = []
}

public protocol MongoConnectionPool {
    func next(for request: ConnectionPoolRequest) async throws -> MongoConnection
    var wireVersion: WireVersion? { get async }
    var sessionManager: MongoSessionManager { get }
    var logger: Logger { get }
}

extension MongoConnection: MongoConnectionPool {
    public func next(for request: ConnectionPoolRequest) async throws -> MongoConnection {
        self
    }
    
    public var wireVersion: WireVersion? {
        get async { await serverHandshake?.maxWireVersion }
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
