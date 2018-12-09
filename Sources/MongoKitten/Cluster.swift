import NIO

// TODO: https://github.com/mongodb/specifications/tree/master/source/server-selection
// TODO: https://github.com/mongodb/specifications/tree/master/source/server-discovery-and-monitoring
// TODO: https://github.com/mongodb/specifications/tree/master/source/max-staleness
// TODO: https://github.com/mongodb/specifications/tree/master/source/initial-dns-seedlist-discovery

public final class Cluster {
    let eventLoop: EventLoop
    let settings: ConnectionSettings
    let sessionManager: SessionManager
    
    /// Set to the lowest version handshake received from MongoDB
    internal var handshakeResult: ConnectionHandshakeReply?
    
    /// The shared ObjectId generator for this cluster
    /// Using the shared generator is more efficient and correct than `ObjectId()`
    internal let sharedGenerator = ObjectIdGenerator()
    
    public var slaveOk = false {
        didSet {
            for connection in pool {
                connection.connection.slaveOk = self.slaveOk
            }
        }
    }
    
    private var pool: [PooledConnection]
    
    /// Returns the database named `database`, on this connection
    public subscript(database: String) -> Database {
        return Database(
            named: database,
            session: sessionManager.makeImplicitSession(for: self)
        )
    }
    
    private init(eventLoop: EventLoop, sessionManager: SessionManager, settings: ConnectionSettings) {
        self.eventLoop = eventLoop
        self.sessionManager = sessionManager
        self.settings = settings
        self.pool = []
        
        // SDAM, monitor online hosts
    }
    
    public static func connect(on group: EventLoopGroup, settings: ConnectionSettings) -> EventLoopFuture<Cluster> {
        let loop = group.next()
        
        guard settings.hosts.count > 0 else {
            return loop.newFailedFuture(error: MongoKittenError(.unableToConnect, reason: .noHostSpecified))
        }
        
        let sessionManager = SessionManager()
        let cluster = Cluster(eventLoop: loop, sessionManager: sessionManager, settings: settings)
        return cluster.makeConnection(writable: true).map { _ in
            return cluster
        }
    }
    
    private func makeConnection(writable: Bool) -> EventLoopFuture<PooledConnection> {
        // TODO: Rely on SDAM to connect to the right host, or server selection
        let host = settings.hosts.first!
        
        // TODO: Failed to connect, different host until all hosts have been had
        return Connection.connect(
            for: self,
            host: settings.hosts.first!
        ).map { connection in
            connection.slaveOk = self.slaveOk
            
            /// Ensures we default to the cluster's lowest version
            if  let connectionHandshake = connection.handshakeResult,
                let clusterHandshake = self.handshakeResult,
                connectionHandshake.maxWireVersion.version < clusterHandshake.maxWireVersion.version
            {
                self.handshakeResult = connectionHandshake
            }
            
            return PooledConnection(host: host, connection: connection)
        }
    }
    
    func getConnection(writable: Bool = true) -> EventLoopFuture<Connection> {
        let matchingConnection = pool.first { pooledConnection in
            if writable && pooledConnection.connection.handshakeResult?.readOnly ?? false {
                return false
            }
            
            return true
        }
        
        if let matchingConnection = matchingConnection {
            return eventLoop.newSucceededFuture(result: matchingConnection.connection)
        }
        
        return makeConnection(writable: writable).map { pooledConnection in
            self.pool.append(pooledConnection)
            
            return pooledConnection.connection
        }
    }
}

struct PooledConnection {
    let host: ConnectionSettings.Host
    let connection: Connection
}
