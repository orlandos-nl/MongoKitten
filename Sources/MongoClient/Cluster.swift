import NIO
import Foundation
import NIOConcurrencyHelpers
import Logging
import DNSClient
import MongoCore

#if canImport(NIOTransportServices) && os(iOS)
import NIOTransportServices

public typealias _MongoPlatformEventLoopGroup = NIOTSEventLoopGroup
#else
public typealias _MongoPlatformEventLoopGroup = EventLoopGroup
#endif

public struct ClusterState {
    public let connectionState: MongoConnectionState
}

/// A high level ``MongoConnectionPool`` type tha is capable of "Service Discovery and Monitoring", automatically connects to new hosts. Is aware of a change in primary/secondary allocation.
///
/// Use this type for connecting to MongoDB unless you have a very specific usecase.
///
/// The ``MongoCluster`` uses ``MongoConnection`` instances under the hood to connect to specific servers, and run specific queries.s
///
/// **Usage**
///
/// ```swift
/// let cluster = try await MongoCluster(
///     lazyConnectingTo: ConnectionSettings("mongodb://localhost")
/// )
/// let database = cluster["testapp"]
/// let users = database["users"]
/// ```
public final class MongoCluster: MongoConnectionPool, @unchecked Sendable {
    public static func _newEventLoopGroup() -> _MongoPlatformEventLoopGroup {
        #if canImport(NIOTransportServices) && os(iOS)
        return NIOTSEventLoopGroup(loopCount: 1)
        #else
        return MultiThreadedEventLoopGroup(numberOfThreads: 1)
        #endif
    }
    
    private var _settings: ConnectionSettings {
        didSet {
            self._hosts = Set(_settings.hosts)
        }
    }
    
    /// The settings used to connect to MongoDB.
    ///
    /// - Note: Might differ from the originally provided settings, since Service Discovery and Monitoring might have discovered more nodes belonging to this MongoDB cluster.
    public private(set) var settings: ConnectionSettings {
        get { lock.withLock { _settings } }
        set {
            lock.withLockVoid { self._settings = newValue }
        }
    }

    private var dns: DNSClient?

    /// Triggers every time the cluster rediscovers
    public var didRediscover: (() -> ())? {
        get { lock.withLock { _didRediscover } }
        set { lock.withLockVoid { _didRediscover = newValue } }
    }
    private var _didRediscover: (() -> ())?

    /// Triggers every time the cluster rediscovers
    public var onStateChange: (@Sendable (ClusterState) -> ())? {
        get { lock.withLock { _onStateChange } }
        set { lock.withLockVoid { _onStateChange = newValue } }
    }
    private var _onStateChange: (@Sendable (ClusterState) -> ())?
    
    public let logger: Logger
    public let sessionManager = MongoSessionManager()

    /// The interval at which cluster discovery is triggered, at a minimum of 500 milliseconds
    ///
    /// - Note: This is not thread safe outside of the cluster's eventloop
    public var heartbeatFrequency = TimeAmount.seconds(10) {
        didSet {
            if heartbeatFrequency < .milliseconds(500) {
                heartbeatFrequency = .milliseconds(500)
            }
        }
    }

    /// The current state of the cluster's connection pool
    ///
    /// - Note: This is not thread safe outside of the cluster's eventloop
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
    ///
    /// - Note: This is not thread safe outside of the cluster's eventloop
    public var slaveOk = false {
        didSet {
            for connection in pool {
                connection.connection.slaveOk.store(self.slaveOk, ordering: .relaxed)
            }
        }
    }

    private let lock = NIOLock()
    
    /// A list of currently open connections
    private var _pool: [PooledConnection]
    private var pool: [PooledConnection] {
        get { lock.withLock { _pool } }
        set { lock.withLockVoid { _pool = newValue } }
    }
    
    /// The WireVersion used by this cluster's nodes
    public private(set) var wireVersion: WireVersion?

    /// If `true`, no connections will be opened and all existing connections will be shut down
    private var isClosed = false

    /// Used as a shortcut to not have to set a callback on `isDiscovering`
    private var completedInitialDiscovery = false
    private var isDiscovering = false
    public var checkLivelinessTimeAmount: TimeInterval?

    /// For initializers where additional initialization logic is kicked off in the background, the task in which this happens is stored here.
    ///
    /// - Note: To not introduce any race conditions on this property, this task is never nilled.
    private var initTask: Task<Void, Error>?

    private init(
        settings: ConnectionSettings,
        logger: Logger,
        eventLoopGroup: _MongoPlatformEventLoopGroup
    ) {
        self._settings = settings
        self._pool = []
        self._hosts = Set(settings.hosts)
        self.logger = logger
        self.group = eventLoopGroup
    }
    
    /// Connects to a cluster lazily, which means you don't know if the connection was successful until you start querying. This is useful when you need a cluster synchronously to query asynchronously
    ///
    /// This initializer also does not need to be `await`ed, making it useful for setting up an application, even under unreliable network conditions.
    ///
    /// - Parameters:
    ///     - settings: The details used to set up a connection to, and authenticate with MongoDB
    ///     - eventLoopGroup: If provided, an existing ``EventLoopGroup`` can be reused. By default, a new one will be created
    ///
    /// ```swift
    /// let cluster = try await MongoCluster(
    ///     lazyConnectingTo: ConnectionSettings("mongodb://localhost")
    /// )
    /// ```
    public convenience init(
        lazyConnectingTo settings: ConnectionSettings,
        logger: Logger = Logger(label: "org.orlandos-nl.mongokitten.cluster"),
        eventLoopGroup: _MongoPlatformEventLoopGroup = MongoCluster._newEventLoopGroup()
    ) throws {
        guard settings.hosts.count > 0 else {
            logger.warning("No MongoDB servers were specified while creating a cluster")
            throw MongoError(.cannotConnect, reason: .noHostSpecified)
        }
        
        self.init(settings: settings, logger: logger, eventLoopGroup: eventLoopGroup)
        
        initTask = Task {
            // Kick off the connection process
            try await resolveSettings()
            
            scheduleDiscovery()
            self.completedInitialDiscovery = true
        }
    }

    /// Connects to a cluster immediately, and awaits connection readiness.
    ///
    /// - Parameters:
    ///     - settings: The details used to set up a connection to, and authenticate with MongoDB
    ///     - allowFailure: If `true`, this method will always succeed - unless your settings are malformed.
    ///     - eventLoopGroup: If provided, an existing ``EventLoopGroup`` can be reused. By default, a new one will be created
    ///
    /// ```swift
    /// let cluster = try await MongoCluster(
    ///     connectingTo: ConnectionSettings("mongodb://localhost")
    /// )
    /// ```
    public convenience init(
        connectingTo settings: ConnectionSettings,
        allowFailure: Bool = false,
        logger: Logger = Logger(label: "org.orlandos-nl.mongokitten.cluster"),
        eventLoopGroup: _MongoPlatformEventLoopGroup = MongoCluster._newEventLoopGroup()
    ) async throws {
        guard settings.hosts.count > 0 else {
            logger.debug("No MongoDB servers were specified while creating a cluster")
            throw MongoError(.cannotConnect, reason: .noHostSpecified)
        }

        self.init(settings: settings, logger: logger, eventLoopGroup: eventLoopGroup)

        // Resolve SRV hostnames
        try await resolveSettings()
        
        _ = try await _getConnection()
        
        // Establish initial connection
        await rediscover()
        self.completedInitialDiscovery = true

        // Check for connectivity
        if self.pool.count == 0, !allowFailure {
            throw MongoError(.cannotConnect, reason: .noAvailableHosts)
        }

        scheduleDiscovery()
    }

    private func scheduleDiscovery() {
        discovering?.cancel()
        discovering = Task { [heartbeatFrequency] in
            if isDiscovering { return }
            
            isDiscovering = true
            defer { isDiscovering = false }
            
            while !isClosed {
                await rediscover()
                didRediscover?()

                try await Task.sleep(nanoseconds: UInt64(heartbeatFrequency.nanoseconds))
            }
        }
    }

    private var discovering: Task<Void, Error>?
    private var _hosts: Set<ConnectionSettings.Host>
    private var hosts: Set<ConnectionSettings.Host> {
        get { lock.withLock { _hosts } }
        set { lock.withLockVoid { _hosts = newValue } }
    }
    
    private var _discoveredHosts = Set<ConnectionSettings.Host>()
    private var discoveredHosts: Set<ConnectionSettings.Host> {
        get { lock.withLock { _discoveredHosts } }
        set { lock.withLockVoid { _discoveredHosts = newValue } }
    }
    private var undiscoveredHosts: Set<ConnectionSettings.Host> {
        return hosts.subtracting(discoveredHosts).subtracting(timeoutHosts)
    }
    private var _timeoutHosts = Set<ConnectionSettings.Host>()
    private var timeoutHosts: Set<ConnectionSettings.Host> {
        get { lock.withLock { _timeoutHosts } }
        set { lock.withLockVoid { _timeoutHosts = newValue } }
    }

    private func updateSDAM(from handshake: ServerHandshake) {
        if let wireVersion = wireVersion {
            self.wireVersion = min(handshake.maxWireVersion, wireVersion)
        } else {
            self.wireVersion = handshake.maxWireVersion
        }
        
        var hosts = handshake.hosts ?? []
        hosts += handshake.passives ?? []

        var topologyChanged = false

        for host in hosts {
            do {
                let host = try ConnectionSettings.Host(host, srv: false)
                topologyChanged = topologyChanged || lock.withLock {
                    if !self._hosts.contains(host) {
                        self._hosts.insert(host)
                        return true
                    } else {
                        return false
                    }
                }
            } catch { }
        }

        if topologyChanged {
            topologyDidChange()
        }
    }

    private func resolveSettings() async throws {
        guard settings.isSRV, let host = settings.hosts.first else {
            return
        }
        
        let client: DNSClient
        
        #if canImport(NIOTransportServices) && os(iOS)
        if let dnsServer = settings.dnsServer {
            let address = try SocketAddress(ipAddress: dnsServer, port: 53)
            client = try await DNSClient.connectTS(on: group, config: [address]).get()
        } else {
            client = try await DNSClient.connectTS(on: group).get()
        }
        #else
        if let dnsServer = settings.dnsServer {
            client = try await DNSClient.connect(on: group, host: dnsServer).get()
        } else {
            client = try await DNSClient.connect(on: group).get()
        }
        #endif
        
        var settings = settings
        settings.hosts = try await resolveSRV(host, on: client)
        self.settings = settings
        self.dns = client
    }

    private func resolveSRV(_ host: ConnectionSettings.Host, on client: DNSClient) async throws -> [ConnectionSettings.Host] {
        let prefix = "_mongodb._tcp."
        return try await client.getSRVRecords(from: prefix + host.hostname).get().map { record in
            return ConnectionSettings.Host(hostname: record.resource.domainName.string, port: Int(record.resource.port))
        }
    }
    
    let group: _MongoPlatformEventLoopGroup

    private func makeConnection(to host: ConnectionSettings.Host) async throws -> PooledConnection {
        if isClosed {
            throw MongoError(.cannotConnect, reason: .connectionClosed)
        }

        logger.debug("Creating new connection to \(host)")
        discoveredHosts.insert(host)
        var settings = self.settings
        settings.hosts = [host]

        do {
            let connection = try await MongoConnection.connect(
                settings: settings,
                logger: logger,
                onGroup: group,
                resolver: self.dns,
                sessionManager: sessionManager
            )
            connection.slaveOk.store(slaveOk, ordering: .relaxed)

            /// Ensures we default to the cluster's lowest version
            if let connectionHandshake = await connection.serverHandshake {
                self.updateSDAM(from: connectionHandshake)
            }

            connection.closeFuture.whenComplete { [weak self, connection] _ in
                guard let me = self else { return }

                Task {
                    await me.remove(connection: connection, error: MongoError(.queryFailure, reason: .connectionClosed))
                }
            }

            return PooledConnection(host: host, connection: connection)
        } catch {
            logger.debug("Connection to \(host) disconnected with error \(error)")
            
            lock.withLockVoid {
                self._timeoutHosts.insert(host)
                self._discoveredHosts.remove(host)
            }
            throw error
        }
    }

    /// Checks all known hosts for isMaster and writability
    private func rediscover() async {
        if isClosed {
            logger.trace("Rediscovering, but the cluster is disconnected")
            return
        }

        self.wireVersion = nil

        await withTaskGroup(of: Void.self) { [settings] taskGroup in
            for pooledConnection in pool {
                let connection = pooledConnection.connection

                taskGroup.addTask {
                    await self.withQueryTimeout(self.heartbeatFrequency) {
                        do {
                            let handshake = try await connection.doHandshake(
                                clientDetails: nil,
                                credentials: settings.authentication
                            )
                            
                            self.updateSDAM(from: handshake)
                        } catch {
                            self.logger.warning("Failed to do handshake: \(error)")
                            await self.remove(connection: connection, error: error)
                        }
                    }
                }
            }

            await taskGroup.waitForAll()
        }
        
        self.timeoutHosts = []
    }

    private func remove(connection: MongoConnection, error: Error) async {
        let pooledConnection: PooledConnection? = lock.withLock {
            if let index = self._pool.firstIndex(where: { $0.connection === connection }) {
                let pooledConnection = self._pool[index]
                self._discoveredHosts.remove(pooledConnection.host)
                return self._pool.remove(at: index)
            } else {
                return nil
            }
        }

        topologyDidChange()
        await pooledConnection?.connection.context.cancelQueries(error)
    }

    private func topologyDidChange() {
        guard let onStateChange else {
            return
        }

        onStateChange(.init(connectionState: connectionState))
    }

    fileprivate func findMatchingExistingConnection(writable: Bool) async -> PooledConnection? {
        var matchingConnection: PooledConnection?

        nextConnection: for pooledConnection in pool {
            let connection = pooledConnection.connection

            guard let handshakeResult = await connection.serverHandshake else {
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

    /// Attempts to create a connection up to `attempts` times
    /// If all's well, this returns a new connection with the requested specifications
    private func makeConnectionRecursively(for request: ConnectionPoolRequest, attempts: Int = 3) async throws -> MongoConnection {
        var attempts = attempts
        while true {
            do {
                if request.requirements.contains(.new) || request.requirements.contains(.notPooled) {
                    // There's no satisfying this request with an existing connection
                    return try await self._createExtraConnection(forRequest: request)
                } else {
                    return try await self._getConnection(writable: request.requirements.contains(.writable) || !slaveOk)
                }
            } catch {
                attempts -= 1
                
                if attempts < 0 {
                    throw error
                }
            }
        }
    }

    /// Gets a connection from the pool, or creates a new one if none are available. The returned connection matches the requirements of the request.
    public func next(for request: ConnectionPoolRequest) async throws -> MongoConnection {
        try await initTask?.value
        return try await self.makeConnectionRecursively(for: request)
    }

    /// Creates an extra connection to an already established host
    private func _createExtraConnection(forRequest request: ConnectionPoolRequest, emptyPoolError: Error? = nil) async throws -> MongoConnection {
        let pooledConnection = try await _getPooledConnection(
            writable: request.requirements.contains(.writable),
            emptyPoolError: emptyPoolError
        )
        
        let newPooledConnection = try await makeConnection(to: pooledConnection.host)
        
        if !request.requirements.contains(.notPooled) {
            lock.withLock {
                self._pool.append(newPooledConnection)
            }

            self.topologyDidChange()
        }
        
        return newPooledConnection.connection
    }
    
    private func _getPooledConnection(writable: Bool = true, emptyPoolError: Error? = nil) async throws -> PooledConnection {
        func createAndPoolConnection(toHost host: ConnectionSettings.Host) async throws -> PooledConnection {
            // make a connection to the provided host and add it to the pool
            let pooledConnection = try await makeConnection(to: host)

            lock.withLock {
                self._pool.append(pooledConnection)
            }

            guard let handshake = await pooledConnection.connection.serverHandshake else {
                throw MongoError(.cannotConnect, reason: .handshakeFailed)
            }

            let unwritable = writable && handshake.readOnly == true
            let unreadable = !self.slaveOk && !handshake.ismaster

            // check if the connection matches our requirements, if not we recursively try again for the next undiscovered host in our list
            if unwritable || unreadable {
                return try await self._getPooledConnection(writable: writable)
            } else {
                return pooledConnection
            }
        }

        if let matchingConnection = await findMatchingExistingConnection(writable: writable) {
            // If the server has been inactive for longer than `checkLivelinessTimeAmount`
            // Ping first to ensure it's actually alive
            // This prevents queries from stalling out and erroring on cloud providers
            // That proactively kill 'stale' or old TCP connections
            if
                let checkLivelinessTimeAmount,
                let lastQuery = await matchingConnection.connection.lastServerActivity,
                lastQuery.addingTimeInterval(checkLivelinessTimeAmount) < Date()
            {
                do {
                    // Check if the connection is alive and well
                    try await matchingConnection.connection.ping()

                    // Return it for use
                    return matchingConnection
                } catch {
                    // Remove the dead connection
                    await remove(connection: matchingConnection.connection, error: error)

                    // Create a new one instead!
                    return try await createAndPoolConnection(toHost: matchingConnection.host)
                }
            } else {
                return matchingConnection
            }
        }
        
        // we grab the first undiscovered host
        guard let host = undiscoveredHosts.first else {
            // if no undiscovered host exists we rediscover and update our list of undiscovered hosts
            await self.rediscover()
            
            // TODO: we can potentially populate a host value from the updated undiscovered host list and continue execution below the guard statement instead of throwing an error
            
            // we throw an error since we could not find a host to connect to
            self.logger.warning("Couldn't find or create a connection to MongoDB with the requested specification. \(timeoutHosts.count) out of \(hosts.count) hosts were in timeout because no TCP connection could be established.")
            throw emptyPoolError ?? MongoError(.cannotConnect, reason: .noAvailableHosts)
        }

        return try await createAndPoolConnection(toHost: host)
    }

    private func _getConnection(writable: Bool = true, emptyPoolError: Error? = nil) async throws -> MongoConnection {
        try await _getPooledConnection(
            writable: writable,
            emptyPoolError: emptyPoolError
        ).connection
    }

    /// Closes all connections, and stops polling for cluster changes.
    ///
    /// - Warning: Any outstanding query results may be cancelled, but the sent query might still be executed.
    public func disconnect() async {
        logger.debug("Disconnecting MongoDB Cluster")
        self.wireVersion = nil
        self.isClosed = true
        self.completedInitialDiscovery = false
        let connections = self.pool
        self.pool = []
        self.discoveredHosts = []

        for pooledConnection in connections {
            await pooledConnection.connection.close()
        }
    }

    /// Prompts ``MongoCluster`` to close all connections, and connect to the remote(s) again.
    ///
    /// - Warning: Any outstanding query results may be cancelled, but the sent query might still be executed.
    ///
    /// - Note: This will also trigger a rediscovery of the cluster.
    public func reconnect() async throws {
        logger.debug("Reconnecting to MongoDB Cluster")
        await disconnect()
        self.isClosed = false
        self.completedInitialDiscovery = false
        _ = try await self.next(for: .writable)
        await rediscover()
        self.completedInitialDiscovery = true
        scheduleDiscovery()
    }
}

fileprivate struct PooledConnection {
    let host: ConnectionSettings.Host
    let connection: MongoConnection
}
