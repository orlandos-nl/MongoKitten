import Foundation
import NIO

#if canImport(NioDNS)
import NioDNS

typealias DNSClient = NioDNS
#else
typealias DNSClient = Void
#endif

internal struct Cancellable<T> {
    let future: EventLoopFuture<T>
    let cancel: () -> ()
}

// TODO: https://github.com/mongodb/specifications/tree/master/source/max-staleness
// TODO: https://github.com/mongodb/specifications/tree/master/source/initial-dns-seedlist-discovery

/// Any MongoDB server connection that's capable of sending queries
public class _ConnectionPool {
    internal let eventLoop: EventLoop

    /// A session pool and gives out session handles with a FIFO policy
    internal let sessionManager: SessionManager

    /// The protocol and feature set supported by the server
    ///
    /// This can change for remote databases, when databases are updated to new versions
    public internal(set) var wireVersion: WireVersion?
    
    /// The shared ObjectId generator for this cluster
    /// Using the shared generator is more efficient and correct than `ObjectId()`
    internal let sharedGenerator = ObjectIdGenerator()
    
    internal init(eventLoop: EventLoop, sessionManager: SessionManager) {
        self.eventLoop = eventLoop
        self.sessionManager = sessionManager
    }
    
    internal func send<C: MongoDBCommand>(command: C, session: ClientSession? = nil, transaction: TransactionQueryOptions? = nil) -> EventLoopFuture<ServerReply> {
        return sendCancellable(command: command, session: session, transaction: transaction).then { $0.future }
    }
    
    internal func sendCancellable<C: MongoDBCommand>(command: C, session: ClientSession? = nil, transaction: TransactionQueryOptions? = nil) -> EventLoopFuture<Cancellable<ServerReply>> {
        fatalError("Subclasses need to implement this")
    }
    
    /// Returns the database named `database`, on this connection
    public subscript(database: String) -> Database {
        return Database(named: database, session: sessionManager.makeImplicitSession(for: self))
    }
}

public enum ConnectionState {
    /// Busy attempting to connect
    case connecting

    /// Connected with <connectionCount> active connections
    case connected(connectionCount: Int)

    /// No connections are open to MongoDB
    case disconnected

    /// The cluster has been shut down
    case closed
}

public final class Cluster: _ConnectionPool {
    private(set) var settings: ConnectionSettings {
        didSet {
            self.hosts = Set(settings.hosts)
        }
    }

    private var dns: DNSClient?

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

    /// The current state of the cluster's connection pool
    public var connectionState: ConnectionState {
        if isClosed {
            return .closed
        }

        if !completedInitialDiscovery {
            return .connecting
        }

        let connectionCount = pool.count

        if connectionCount == 0 {
            return .disconnected
        }

        return .connected(connectionCount: connectionCount)
    }

    /// Reflects if MongoKitten finds the remote to be a multi-server cluster setup
    public var isCluster: Bool {
        return hosts.count > 1
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
    let group: PlatformEventLoopGroup
    private var newWireVersion: WireVersion?

    /// If `true`, no connections will be opened and all existing connections will be shut down
    private var isClosed = false

    /// Used as a shortcut to not have to set a callback on `isDiscovering`
    private var completedInitialDiscovery = false
    
    private init(group: PlatformEventLoopGroup, sessionManager: SessionManager, settings: ConnectionSettings) {
        let eventLoop = group.next()
        
        self.group = group
        self.settings = settings
        self.isDiscovering = eventLoop.newPromise()
        self.pool = []
        self.hosts = Set(settings.hosts)
    
        super.init(eventLoop: eventLoop, sessionManager: sessionManager)
    }
    
    /// Connects to a cluster lazily, which means you don't know if the connection was successful until you start querying
    ///
    /// This is useful when you need a cluster synchronously to query asynchronously
    public convenience init(lazyConnectingTo settings: ConnectionSettings, on group: PlatformEventLoopGroup) throws {
        guard settings.hosts.count > 0 else {
            throw MongoKittenError(.unableToConnect, reason: .noHostSpecified)
        }
        
        self.init(group: group, sessionManager: SessionManager(), settings: settings)
        
        Cluster.withResolvedSettings(settings, on: group.next()) { settings, dns -> EventLoopFuture<Void> in
            self.settings = settings
            self.dns = dns
            
            return self._getConnection().then { _ in
                return self.rediscover()
            }
        }.whenComplete {
            self.completedInitialDiscovery = true

            if self.pool.count > 0 {
                self.isDiscovering.succeed(result: ())
            } else {
                self.isDiscovering.fail(error: MongoKittenError(.unableToConnect, reason: .noAvailableHosts))
            }
        }
        
        self.isDiscovering.futureResult.whenComplete(self.scheduleDiscovery)
    }
    
    private func _send(context: MongoDBCommandContext) -> EventLoopFuture<ServerReply> {
        let future = self.getConnection().thenIfError { _ in
            return self.getConnection(writable: true)
        }.then { connection -> EventLoopFuture<Void> in
            connection.context.queries.append(context)
            return connection.channel.writeAndFlush(context)
        }
        future.cascadeFailure(promise: context.promise)
        
        return future.then { context.promise.futureResult }
    }
    
    override func sendCancellable<C>(command: C, session: ClientSession? = nil, transaction: TransactionQueryOptions? = nil) -> EventLoopFuture<Cancellable<ServerReply>> where C : MongoDBCommand {
        return self.getConnection().thenIfError { _ in
            return self.getConnection(writable: true)
        }.then { connection -> EventLoopFuture<Cancellable<ServerReply>> in
            let requestId = connection.nextRequestId()
            let promise = self.eventLoop.newPromise(of: ServerReply.self)
            
            let context = MongoDBCommandContext(
                command: command,
                requestID: requestId,
                retry: true,
                session: session,
                transaction: transaction,
                promise: promise
            )
            
            connection.context.queries.append(context)
            
            return connection.channel.writeAndFlush(context).map {
                return Cancellable(future: promise.futureResult) {
                    connection.context.cancel(byId: requestId)
                }
            }
        }
    }
    
    /// Connects to a cluster asynchronously
    ///
    /// You can query it using the Cluster returned from the future
    public static func connect(on group: PlatformEventLoopGroup, settings: ConnectionSettings) -> EventLoopFuture<Cluster> {
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

            self.rediscover().whenComplete(self.scheduleDiscovery)
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
                let host = try ConnectionSettings.Host(host, srv: false)
                self.hosts.insert(host)
            } catch { }
        }
    }
    
    private static func withResolvedSettings<T>(_ settings: ConnectionSettings, on loop: EventLoop, run: @escaping (ConnectionSettings, DNSClient?) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        if !settings.isSRV {
            return run(settings, nil)
        }

        #if canImport(NioDNS)
        let host = settings.hosts.first!

        return DNSClient.connect(on: loop).then { client in
            let srv = resolveSRV(host, on: client)
            let txt = resolveTXT(host, on: client)
            return srv.and(txt).then { hosts, query in
                var settings = settings
                // TODO: Use query
                settings.hosts = hosts
                return run(settings, client)
            }
        }
        #else
        return run(settings, nil)
        #endif
    }

    #if canImport(NioDNS)
    private static func resolveTXT(_ host: ConnectionSettings.Host, on client: DNSClient) -> EventLoopFuture<String?> {
        return client.sendQuery(forHost: host.hostname, type: .txt).map { message -> String? in
            guard let answer = message.answers.first else { return nil }
            guard case .txt(let txt) = answer else { return nil }
            return txt.resource.text
        }
    }

    private static let prefix = "_mongodb._tcp."
    private static func resolveSRV(_ host: ConnectionSettings.Host, on client: DNSClient) -> EventLoopFuture<[ConnectionSettings.Host]> {
        let srvRecords = client.getSRVRecords(from: prefix + host.hostname)

        return srvRecords.map { records in
            return records.map { record in
                return ConnectionSettings.Host(hostname: record.resource.domainName.string, port: host.port)
            }
        }
    }
    #endif
    
    private func makeConnection(to host: ConnectionSettings.Host) -> EventLoopFuture<PooledConnection> {
        if isClosed {
            return eventLoop.newFailedFuture(error: MongoKittenError(.unableToConnect, reason: .connectionClosed))
        }

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
        if isClosed {
            return eventLoop.newFailedFuture(error: MongoKittenError(.unableToConnect, reason: .connectionClosed))
        }

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
                    _ = self._send(context: query)
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

    /// Closes all connections
    @discardableResult
    public func disconnect() -> EventLoopFuture<Void> {
        self.isClosed = true
        let connections = self.pool
        self.pool = []

        let closed = connections.map { remote in
            return remote.connection.close()
        }

        return EventLoopFuture<Void>.andAll(closed, eventLoop: eventLoop)
    }

    /// Prompts MongoKitten to connect to the remote again
    public func reconnect() -> EventLoopFuture<Void> {
        self.isClosed = false

        return self.getConnection().map { _ in }
    }
}

struct PooledConnection {
    let host: ConnectionSettings.Host
    let connection: Connection
}
