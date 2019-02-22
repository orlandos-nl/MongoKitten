import Foundation
import NIO

// TODO: https://github.com/mongodb/specifications/tree/master/source/max-staleness
// TODO: https://github.com/mongodb/specifications/tree/master/source/initial-dns-seedlist-discovery

public final class Cluster {
    let eventLoop: EventLoop
    let settings: ConnectionSettings
    let sessionManager: SessionManager
    
    /// The shared ObjectId generator for this cluster
    /// Using the shared generator is more efficient and correct than `ObjectId()`
    internal let sharedGenerator = ObjectIdGenerator()
    
    /// The interval at which cluster discovery is triggered, at a minimum of 500 milliseconds
    ///
    /// This is not thread safe outside of the cluster's eventloop
    public var heartbeatFrequency = TimeAmount.seconds(10) {
        didSet {
            if heartbeatFrequency < .milliseconds(500) {
                heartbeatFrequency = .milliseconds(500)
            }
        }
    }
    
    /// When set to true, read queries are also executed on slave instances of MongoDB
    public var slaveOk = false {
        didSet {
            for connection in pool {
                connection.connection.slaveOk = self.slaveOk
            }
        }
    }
    
    private let isDiscovering: EventLoopPromise<Void>
    private var pool: [PooledConnection]
    internal private(set) var wireVersion: WireVersion?
    private var newWireVersion: WireVersion?
    
    /// Used as a shortcut to not have to set a callback on `isDiscovering`
    private var completedInitialDiscovery = false
    
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
        self.isDiscovering = eventLoop.newPromise()
        self.pool = []
        self.hosts = Set(settings.hosts)
    }
    
    /// Connects to a cluster lazily, which means you don't know if the connection was successful until you start querying
    ///
    /// This is useful when you need a cluster synchronously to query asynchronously
    public convenience init(lazyConnectingTo settings: ConnectionSettings, on group: EventLoopGroup) throws {
        guard settings.hosts.count > 0 else {
            throw MongoKittenError(.unableToConnect, reason: .noHostSpecified)
        }
        
        self.init(eventLoop: group.next(), sessionManager: SessionManager(), settings: settings)
        
        self._getConnection().then { _ in
            return self.rediscover()
        }.whenComplete {
            if self.pool.count > 0 {
                self.completedInitialDiscovery = true
                self.isDiscovering.succeed(result: ())
            } else {
                self.isDiscovering.fail(error: MongoKittenError(.unableToConnect, reason: .noAvailableHosts))
            }
        }
        
        self.isDiscovering.futureResult.whenComplete(self.scheduleDiscovery)
    }
    
    private func send(context: MongoDBCommandContext) -> EventLoopFuture<ServerReply> {
        let future = self.getConnection().thenIfError { _ in
            return self.getConnection(writable: true)
            }.then { connection -> EventLoopFuture<Void> in
                connection.context.queries.append(context)
                return connection.channel.writeAndFlush(context)
        }
        future.cascadeFailure(promise: context.promise)
        
        return future.then { context.promise.futureResult }
    }
    
    func send<C: MongoDBCommand>(command: C, session: ClientSession? = nil, transaction: TransactionQueryOptions? = nil) -> EventLoopFuture<ServerReply> {
        let context = MongoDBCommandContext(
            command: command,
            requestID: 0,
            retry: true,
            session: session,
            transaction: transaction,
            promise: self.eventLoop.newPromise()
        )
        
        return send(context: context)
    }
    
    /// Connects to a cluster asynchronously
    ///
    /// You can query it using the Cluster returned from the future
    public static func connect(on group: EventLoopGroup, settings: ConnectionSettings) -> EventLoopFuture<Cluster> {
        do {
            let cluster = try Cluster(lazyConnectingTo: settings, on: group)
            return cluster.isDiscovering.futureResult.map { cluster }
        } catch {
            return group.next().newFailedFuture(error: error)
        }
    }
    
    private func scheduleDiscovery() {
        _ = eventLoop.scheduleTask(in: heartbeatFrequency) { [weak self] in
            guard let `self` = self else { return }
            
            self.rediscover().whenSuccess(self.scheduleDiscovery)
        }
    }
    
    private var hosts: Set<ConnectionSettings.Host>
    private var discoveredHosts = Set<ConnectionSettings.Host>()
    private var undiscoveredHosts: Set<ConnectionSettings.Host> {
        return hosts.subtracting(discoveredHosts).subtracting(timeoutHosts)
    }
    private var timeoutHosts = Set<ConnectionSettings.Host>()
    
    private func updateSDAM(from handshake: ConnectionHandshakeReply) {
        if let newWireVersion = newWireVersion {
            self.newWireVersion = min(handshake.maxWireVersion, newWireVersion)
        } else {
            self.newWireVersion = handshake.maxWireVersion
        }
        
        var hosts = handshake.hosts ?? []
        hosts += handshake.passives ?? []
        
        for host in hosts {
            do {
                let host = try ConnectionSettings.Host(host)
                self.hosts.insert(host)
            } catch { }
        }
    }
    
    private func makeConnection(to host: ConnectionSettings.Host) -> EventLoopFuture<PooledConnection> {
        discoveredHosts.insert(host)
        
        // TODO: Failed to connect, different host until all hosts have been had
        let connection = Connection.connect(
            for: self,
            host: host
            ).map { connection -> PooledConnection in
                connection.slaveOk = self.slaveOk
                
                /// Ensures we default to the cluster's lowest version
                if let connectionHandshake = connection.handshakeResult {
                    self.updateSDAM(from: connectionHandshake)
                }
                
                let connectionId = ObjectIdentifier(connection)
                connection.channel.closeFuture.whenComplete { [weak self] in
                    guard let me = self else { return }
                    
                    me.remove(connectionId: connectionId)
                }
                
                return PooledConnection(host: host, connection: connection)
        }
        
        connection.whenFailure { error in
            self.timeoutHosts.insert(host)
            self.discoveredHosts.remove(host)
        }
        
        return connection
    }
    
    /// Checks all known hosts for isMaster and writability
    private func rediscover() -> EventLoopFuture<Void> {
        self.newWireVersion = nil
        var handshakes = [EventLoopFuture<Void>]()
        
        for pooledConnection in pool {
            let handshake = pooledConnection.connection.executeHandshake(withClientMetadata: false)
            handshake.whenSuccess {
                if let handshake = pooledConnection.connection.handshakeResult {
                    self.updateSDAM(from: handshake)
                }
            }
            handshake.whenFailure { _ in
                self.discoveredHosts.remove(pooledConnection.host)
            }
            
            handshakes.append(handshake)
        }
        
        self.timeoutHosts = []
        let completedDiscovery = EventLoopFuture<Void>.andAll(handshakes, eventLoop: self.eventLoop)
        completedDiscovery.whenComplete {
            self.wireVersion = self.newWireVersion
        }
        
        return completedDiscovery
    }
    
    private func remove(connectionId: ObjectIdentifier) {
        if let index = self.pool.firstIndex(where: { ObjectIdentifier($0.connection) == connectionId }) {
            let pooledConnection = self.pool[index]
            self.pool.remove(at: index)
            self.discoveredHosts.remove(pooledConnection.host)
            pooledConnection.connection.context.prepareForResend()
            
            let rediscovery = self.rediscover()
            let queries = pooledConnection.connection.context.queries
            
            rediscovery.whenSuccess {
                for query in queries {
                    // Retry the query
                    _ = self.send(context: query)
                }
            }
            
            rediscovery.whenFailure { error in
                for query in queries {
                    // Retry the query
                    query.promise.fail(error: error)
                }
            }
            
            // So they don't get failed on deinit of the connection
            pooledConnection.connection.context.queries = []
        }
    }
    
    func findMatchingConnection(writable: Bool) -> PooledConnection? {
        var matchingConnection: PooledConnection?
        
        nextConnection: for pooledConnection in pool {
            let connection = pooledConnection.connection
            
            guard !connection.context.isClosed, let handshakeResult = connection.handshakeResult else {
                self.remove(connectionId: ObjectIdentifier(connection))
                continue nextConnection
            }
            
            let unwritable = writable && handshakeResult.readOnly ?? false
            let unreadable = !self.slaveOk && !handshakeResult.ismaster
            
            if unwritable || unreadable {
                continue nextConnection
            }
            
            matchingConnection = pooledConnection
        }
        
        return matchingConnection
    }
    
    func getConnection(writable: Bool = true) -> EventLoopFuture<Connection> {
        if completedInitialDiscovery {
            return self._getConnection(writable: writable)
        }
        
        return isDiscovering.futureResult.then {
            return self._getConnection(writable: writable)
        }
    }
    
    private func _getConnection(writable: Bool = true) -> EventLoopFuture<Connection> {
        if let matchingConnection = findMatchingConnection(writable: writable) {
            return eventLoop.newSucceededFuture(result: matchingConnection.connection)
        }
        
        guard let host = undiscoveredHosts.first else {
            return self.rediscover().thenThrowing { _ in
                guard let match = self.findMatchingConnection(writable: writable) else {
                    throw MongoKittenError(.unableToConnect, reason: .noAvailableHosts)
                }
                
                return match.connection
            }
        }
        
        return makeConnection(to: host).then { pooledConnection in
            self.pool.append(pooledConnection)
            
            guard let handshake = pooledConnection.connection.handshakeResult else {
                return self.eventLoop.newFailedFuture(error: MongoKittenError(.unableToConnect, reason: .handshakeFailed))
            }
            
            let unwritable = writable && handshake.readOnly == true
            let unreadable = !self.slaveOk && !handshake.ismaster
            
            if unwritable || unreadable {
                return self._getConnection(writable: writable)
            } else {
                return self.eventLoop.newSucceededFuture(result: pooledConnection.connection)
            }
        }
    }
}

struct PooledConnection {
    let host: ConnectionSettings.Host
    let connection: Connection
}
