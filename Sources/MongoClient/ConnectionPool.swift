import NIO
import Logging
import MongoCore

/// The requirements for a connection in a connection pool request. A connection pool request can have multiple requirements.
public struct ConnectionPoolRequirement: Hashable, Sendable {
    internal enum _Requirement: Hashable, Sendable {
        case writable, new, notPooled
    }
    
    let raw: _Requirement
    
    /// A connection that can be used for writing data, such as ceating a new collection or inserting data
    public static let writable = ConnectionPoolRequirement(raw: .writable)

    /// A connection that has not been used before
    public static let new = ConnectionPoolRequirement(raw: .new)

    /// A connection that is not pooled and will not be returned to the pool
    public static let notPooled = ConnectionPoolRequirement(raw: .notPooled)
}

/// A request for a connection from a connection pool
public struct ConnectionPoolRequest: Sendable, ExpressibleByArrayLiteral {
    public let requirements: Set<ConnectionPoolRequirement>
    
    public init(arrayLiteral requirements: ConnectionPoolRequirement...) {
        self.requirements = Set(requirements)
    }
    
    public static let writable: ConnectionPoolRequest = [.writable]
    public static let basic: ConnectionPoolRequest = []
}

/// A connection pool that can be used to get connections from
public protocol MongoConnectionPool {
    /// Gets a connection from the pool that matches the provided `request`
    func next(for request: ConnectionPoolRequest) async throws -> MongoConnection

    var wireVersion: WireVersion? { get async }
    var sessionManager: MongoSessionManager { get }
    var logger: Logger { get }
}

/// A connection pool that only ever uses a single connection and does not pool connections
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
