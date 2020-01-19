import NIO
import Logging
import DNSClient
import MongoCore

#if canImport(NIOTransportServices)
import NIOTransportServices

public typealias _MongoPlatformEventLoopGroup = NIOTSEventLoopGroup
#else
public typealias _MongoPlatformEventLoopGroup = EventLoopGroup
#endif

public final class MongoCluster: MongoConnectionPool {
    public private(set) var settings: ConnectionSettings {
        didSet {
            self.hosts = Set(settings.hosts)
        }
    }

    private var dns: DNSClient?
    public let logger: Logger
    public let sessionManager = MongoSessionManager()

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
    public var connectionState: MongoConnectionState {
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

    /// When set to true, read queries are also executed on slave instances of MongoDB
    public var slaveOk = false {
        didSet {
            for connection in pool {
                connection.connection.slaveOk = self.slaveOk
            }
        }
    }

    private let isDiscovering: EventLoopPromise<Void>
    public var initialDiscovery: EventLoopFuture<Void> {
        return isDiscovering.futureResult
    }

    private var pool: [PooledConnection]
    private let group: _MongoPlatformEventLoopGroup
    public let eventLoop: EventLoop
    public private(set) var wireVersion: WireVersion?

    /// If `true`, no connections will be opened and all existing connections will be shut down
    private var isClosed = false

    /// Used as a shortcut to not have to set a callback on `isDiscovering`
    private var completedInitialDiscovery = false

    private init(
        group: _MongoPlatformEventLoopGroup,
        settings: ConnectionSettings,
        logger: Logger
    ) {
        self.eventLoop = group.next()
        self.group = group
        self.settings = settings
        self.isDiscovering = eventLoop.makePromise()
        self.pool = []
        self.hosts = Set(settings.hosts)
        self.logger = logger
    }

    /// Connects to a cluster lazily, which means you don't know if the connection was successful until you start querying
    ///
    /// This is useful when you need a cluster synchronously to query asynchronously
    public convenience init(
        lazyConnectingTo settings: ConnectionSettings,
        on group: _MongoPlatformEventLoopGroup,
        logger: Logger = .defaultMongoCore
    ) throws {
        guard settings.hosts.count > 0 else {
            logger.error("No MongoDB servers were specified while creating a cluster")
            throw MongoError(.cannotConnect, reason: .noHostSpecified)
        }

        self.init(group: group, settings: settings, logger: logger)

        MongoCluster.withResolvedSettings(settings, on: group.next()) { settings, dns -> EventLoopFuture<Void> in
            self.settings = settings
            self.dns = dns

            return self.makeConnectionRecursively(for: .init(writable: false), emptyPoolError: nil).flatMap { _ in
                return self.rediscover()
            }
        }.whenComplete { _ in
            self.completedInitialDiscovery = true

            if self.pool.count > 0 {
                self.isDiscovering.succeed(())
            } else {
                self.isDiscovering.fail(MongoError(.cannotConnect, reason: .noAvailableHosts))
            }
        }

        self.initialDiscovery.whenComplete { _ in self.scheduleDiscovery() }
    }

    /// Connects to a cluster asynchronously
    ///
    /// You can query it using the Cluster returned from the future
    public static func connect(on group: _MongoPlatformEventLoopGroup, settings: ConnectionSettings) -> EventLoopFuture<MongoCluster> {
        do {
            let cluster = try MongoCluster(lazyConnectingTo: settings, on: group)
            return cluster.initialDiscovery.map { cluster }
        } catch {
            return group.next().makeFailedFuture(error)
        }
    }

    private func scheduleDiscovery() {
        _ = eventLoop.scheduleTask(in: heartbeatFrequency) { [weak self] in
            self?.rediscover().whenComplete { _ in self?.scheduleDiscovery() }
        }
    }

    private var hosts: Set<ConnectionSettings.Host>
    private var discoveredHosts = Set<ConnectionSettings.Host>()
    private var undiscoveredHosts: Set<ConnectionSettings.Host> {
        return hosts.subtracting(discoveredHosts).subtracting(timeoutHosts)
    }
    private var timeoutHosts = Set<ConnectionSettings.Host>()

    private func updateSDAM(from handshake: ServerHandshake) {
        if let wireVersion = wireVersion {
            self.wireVersion = min(handshake.maxWireVersion, wireVersion)
        } else {
            self.wireVersion = handshake.maxWireVersion
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

        let host = settings.hosts.first!

        return DNSClient.connect(on: loop).flatMap { client in
            let srv = resolveSRV(host, on: client)
            let txt = resolveTXT(host, on: client)
            return srv.and(txt).flatMap { hosts, query in
                var settings = settings
                // TODO: Use query
                settings.hosts = hosts
                return run(settings, client)
            }
        }
    }

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

    private func makeConnection(to host: ConnectionSettings.Host) -> EventLoopFuture<PooledConnection> {
        if isClosed {
            return eventLoop.makeFailedFuture(MongoError(.cannotConnect, reason: .connectionClosed))
        }

        discoveredHosts.insert(host)
        var settings = self.settings
        settings.hosts = [host]

        // TODO: Failed to connect, different host until all hosts have been had
        let connection = MongoConnection.connect(
            settings: settings,
            on: eventLoop,
            logger: logger,
            resolver: self.dns,
            sessionManager: sessionManager
        ).map { connection -> PooledConnection in
            connection.slaveOk = self.slaveOk

            /// Ensures we default to the cluster's lowest version
            if let connectionHandshake = connection.serverHandshake {
                self.updateSDAM(from: connectionHandshake)
            }

            let connectionId = ObjectIdentifier(connection)
            connection.closeFuture.whenComplete { [weak self] _ in
                guard let me = self else { return }

                me.remove(connectionId: connectionId, error: MongoError(.queryFailure, reason: .connectionClosed))
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
            return eventLoop.makeFailedFuture(MongoError(.cannotConnect, reason: .connectionClosed))
        }

        self.wireVersion = nil
        var handshakes = [EventLoopFuture<Void>]()

        for pooledConnection in pool {
            let handshake = pooledConnection.connection.doHandshake(clientDetails: nil, credentials: settings.authentication)
            handshake.whenFailure { _ in
                self.discoveredHosts.remove(pooledConnection.host)
            }

            handshakes.append(handshake.map { handshake in
                self.updateSDAM(from: handshake)
            })
        }

        self.timeoutHosts = []
        return EventLoopFuture<Void>.andAllComplete(handshakes, on: self.eventLoop)
    }

    private func remove(connectionId: ObjectIdentifier, error: Error) {
        if let index = self.pool.firstIndex(where: { ObjectIdentifier($0.connection) == connectionId }) {
            let pooledConnection = self.pool[index]
            self.pool.remove(at: index)
            self.discoveredHosts.remove(pooledConnection.host)
            pooledConnection.connection.context.cancelQueries(error)
        }
    }

    fileprivate func findMatchingConnection(writable: Bool) -> PooledConnection? {
        var matchingConnection: PooledConnection?

        nextConnection: for pooledConnection in pool {
            let connection = pooledConnection.connection

            guard let handshakeResult = connection.serverHandshake else {
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
    
    private func makeConnectionRecursively(for request: MongoConnectionPoolRequest, emptyPoolError: Error?, attempts: Int = 3) -> EventLoopFuture<MongoConnection> {
        return self._getConnection(writable: request.writable).flatMapError { error in
            if attempts <= 0 {
                return self.eventLoop.makeFailedFuture(error)
            }
            
            return self.makeConnectionRecursively(for: request, emptyPoolError: error, attempts: attempts - 1)
        }
    }

    public func next(for request: MongoConnectionPoolRequest) -> EventLoopFuture<MongoConnection> {
        if completedInitialDiscovery {
            return makeConnectionRecursively(for: request, emptyPoolError: nil)
        }

        return isDiscovering.futureResult.flatMap {
            return self.makeConnectionRecursively(for: request, emptyPoolError: nil)
        }
    }

    private func _getConnection(writable: Bool = true, emptyPoolError: Error? = nil) -> EventLoopFuture<MongoConnection> {
        if let matchingConnection = findMatchingConnection(writable: writable) {
            return eventLoop.makeSucceededFuture(matchingConnection.connection)
        }

        guard let host = undiscoveredHosts.first else {
            return self.rediscover().flatMapThrowing { _ in
                guard let match = self.findMatchingConnection(writable: writable) else {
                    self.logger.error("Couldn't find or create a connection to MongoDB with the requested specification")
                    throw emptyPoolError ?? MongoError(.cannotConnect, reason: .noAvailableHosts)
                }

                return match.connection
            }
        }

        return makeConnection(to: host).flatMap { pooledConnection in
            self.pool.append(pooledConnection)

            guard let handshake = pooledConnection.connection.serverHandshake else {
                return self.eventLoop.makeFailedFuture(MongoError(.cannotConnect, reason: .handshakeFailed))
            }

            let unwritable = writable && handshake.readOnly == true
            let unreadable = !self.slaveOk && !handshake.ismaster

            if unwritable || unreadable {
                return self._getConnection(writable: writable)
            } else {
                return self.eventLoop.makeSucceededFuture(pooledConnection.connection)
            }
        }
    }

    /// Closes all connections
    @discardableResult
    public func disconnect() -> EventLoopFuture<Void> {
        self.wireVersion = nil
        self.isClosed = true
        let connections = self.pool
        self.pool = []

        let closed = connections.map { remote in
            return remote.connection.close()
        }

        return EventLoopFuture<Void>.andAllComplete(closed, on: eventLoop)
    }

    /// Prompts MongoKitten to connect to the remote again
    public func reconnect() -> EventLoopFuture<Void> {
        return disconnect().flatMap {
            self.isClosed = false

            return self.next(for: MongoConnectionPoolRequest(writable: false)).map { _ in }
        }
    }
}

fileprivate struct PooledConnection {
    let host: ConnectionSettings.Host
    let connection: MongoConnection
}
