import NIO

// TODO: https://github.com/mongodb/specifications/tree/master/source/server-selection
// TODO: https://github.com/mongodb/specifications/tree/master/source/server-discovery-and-monitoring
// TODO: https://github.com/mongodb/specifications/tree/master/source/max-staleness
// TODO: https://github.com/mongodb/specifications/tree/master/source/initial-dns-seedlist-discovery

public final class Cluster {
    let eventLoop: EventLoop
    let settings: ConnectionSettings
    let sessionManager: SessionManager
    private var pool: [PooledConnection]
    
    private init(eventLoop: EventLoop, sessionManager: SessionManager, settings: ConnectionSettings, initialConnection connection: PooledConnection) {
        self.eventLoop = eventLoop
        self.sessionManager = sessionManager
        self.settings = settings
        self.pool = [connection]
        
        // SDAM, monitor online hosts
    }
    
    public static func connect(on group: EventLoopGroup, settings: ConnectionSettings) -> EventLoopFuture<Cluster> {
        let loop = group.next()
        
        guard settings.hosts.count > 0 else {
            return loop.newFailedFuture(error: MongoKittenError(.unableToConnect, reason: .noHostSpecified))
        }
        
        let autoSelectedHost = settings.hosts.first!
        let sessionManager = SessionManager()
        
        return Connection.connect(
            on: group,
            sessionManager: sessionManager,
            settings: settings,
            host: autoSelectedHost
        ).map { connection in
            let pooledConection = PooledConnection(host: autoSelectedHost, connection: connection)
            return Cluster(eventLoop: loop, sessionManager: sessionManager, settings: settings, initialConnection: pooledConection)
        }
    }
    
    private func makeConnection(writable: Bool) -> EventLoopFuture<PooledConnection> {
        // TODO: Rely on SDAM to connect to the right host, or server selection
        let host = settings.hosts.first!
        
        // TODO: Failed to connect, different host until all hosts have been had
        return Connection.connect(
            on: eventLoop,
            sessionManager: sessionManager,
            settings: settings,
            host: host
        ).map { connection in
            return PooledConnection(host: host, connection: connection)
        }
    }
    
    public func getConnection(writable: Bool = true) -> EventLoopFuture<Connection> {
        let matchingConnection = pool.first { pooledConnection in
            if writable && pooledConnection.connection.handshakeResult.readOnly ?? false {
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
