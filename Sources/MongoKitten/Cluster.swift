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
    
    private func send(context: MongoDBCommandContext) -> EventLoopFuture<ServerReply> {
        let future = self.getConnection().thenIfError { _ in
            return self.makeConnection(writable: true).map { $0.connection }
        }.then { connection -> EventLoopFuture<Void> in
            connection.context.queries.append(context)
            return connection.channel.writeAndFlush(context)
        }
        future.cascadeFailure(promise: context.promise)
        
        return future.then { context.promise.futureResult }
    }
    
    func send<C: MongoDBCommand>(command: C, session: ClientSession? = nil) -> EventLoopFuture<ServerReply> {
        let context = MongoDBCommandContext(
            command: command,
            requestID: 0,
            retry: true,
            session: session,
            promise: self.eventLoop.newPromise()
        )
        
        return send(context: context)
    }
    
    public static func connect(on group: EventLoopGroup, settings: ConnectionSettings) -> EventLoopFuture<Cluster> {
        let loop = group.next()
        
        guard settings.hosts.count > 0 else {
            return loop.newFailedFuture(error: MongoKittenError(.unableToConnect, reason: .noHostSpecified))
        }
        
        let sessionManager = SessionManager()
        let cluster = Cluster(eventLoop: loop, sessionManager: sessionManager, settings: settings)
        return cluster.getConnection().map { _ in
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
            if let connectionHandshake = connection.handshakeResult {
                if let clusterHandshake = self.handshakeResult {
                    if clusterHandshake.maxWireVersion.version > connectionHandshake.maxWireVersion.version {
                        self.handshakeResult = connectionHandshake
                    }
                } else {
                    self.handshakeResult = connectionHandshake
                }
            }
            
            let connectionId = ObjectIdentifier(connection)
            connection.channel.closeFuture.whenComplete { [weak self] in
                guard let me = self else { return }
                
                if let index = me.pool.firstIndex(where: { ObjectIdentifier($0.connection) == connectionId }) {
                    let connection = me.pool[index].connection
                    me.pool.remove(at: index)
                    connection.context.prepareForResend()
                    
                    for query in connection.context.queries {
                        _ = me.send(context: query)
                    }
                    
                    // So they don't get failed on deinit of the connection
                    connection.context.queries = []
                }
            }
            
            return PooledConnection(host: host, connection: connection)
        }
    }
    
    func getConnection(writable: Bool = true) -> EventLoopFuture<Connection> {
        var index = pool.count
        var matchingConnection: PooledConnection?
        
        nextConnection: while index > 0 {
            index = index &- 1
            let pooledConnection = pool[index]
            let connection = pooledConnection.connection
            
            if connection.context.isClosed {
                self.pool.remove(at: index)
                continue nextConnection
            }
            
            if writable && handshakeResult?.readOnly ?? false {
                continue nextConnection
            }
            
            matchingConnection = pooledConnection
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
