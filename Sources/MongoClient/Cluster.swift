import NIO
import Logging
import DNSClient
import MongoCore

#if canImport(NIOTransportServices) && os(iOS)
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
    
    /// Triggers every time the cluster rediscovers
    ///
    /// This is not thread safe outside of the cluster's eventloop
    public var didRediscover: (() -> ())?
    
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
    ///
    /// This is not thread safe outside of the cluster's eventloop
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
    /// This is not thread safe outside of the cluster's eventloop
    public var slaveOk = false {
        didSet {
            for connection in pool {
                connection.connection.slaveOk = self.slaveOk
            }
        }
    }

    /// A list of currently open connections
    private var pool: [PooledConnection]
    
    /// The WireVersion used by this cluster's nodes
    public private(set) var wireVersion: WireVersion?

    /// If `true`, no connections will be opened and all existing connections will be shut down
    private var isClosed = false

    /// Used as a shortcut to not have to set a callback on `isDiscovering`
    private var completedInitialDiscovery = false
    private var isDiscovering = false

    private init(
        settings: ConnectionSettings,
        logger: Logger
    ) {
        self.settings = settings
        self.pool = []
        self.hosts = Set(settings.hosts)
        self.logger = logger
    }
    
    /// Connects to a cluster lazily, which means you don't know if the connection was successful until you start querying
    ///
    /// This is useful when you need a cluster synchronously to query asynchronously
    public convenience init(
        lazyConnectingTo settings: ConnectionSettings,
        logger: Logger = Logger(label: "org.openkitten.mongokitten.cluster")
    ) throws {
        guard settings.hosts.count > 0 else {
            logger.error("No MongoDB servers were specified while creating a cluster")
            throw MongoError(.cannotConnect, reason: .noHostSpecified)
        }
        
        self.init(settings: settings, logger: logger)
        
        Task {
            // Kick off the connection process
            try await MongoCluster.withResolvedSettings(settings) { settings, dns in
                self.settings = settings
                self.dns = dns
            }
            
            scheduleDiscovery()
        }
    }

    public convenience init(
        connectingTo settings: ConnectionSettings,
        allowFailure: Bool = false,
        logger: Logger = Logger(label: "org.openkitten.mongokitten.cluster")
    ) async throws {
        guard settings.hosts.count > 0 else {
            logger.error("No MongoDB servers were specified while creating a cluster")
            throw MongoError(.cannotConnect, reason: .noHostSpecified)
        }

        self.init(settings: settings, logger: logger)

        try await MongoCluster.withResolvedSettings(settings) { settings, dns in
            self.settings = settings
            self.dns = dns
        }

        if self.pool.count == 0, !allowFailure {
            throw MongoError(.cannotConnect, reason: .noAvailableHosts)
        }

        scheduleDiscovery()
    }

    @discardableResult
    private func scheduleDiscovery() -> Task<Void, Never> {
        return Task {
            if isDiscovering { return }
            
            isDiscovering = true
            defer { isDiscovering = false }
            
            while !isClosed {
                await rediscover()
            }
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

    private static func withResolvedSettings<T>(_ settings: ConnectionSettings, run: @Sendable @escaping (ConnectionSettings, DNSClient?) async throws -> T) async throws -> T {
        if !settings.isSRV {
            return try await run(settings, nil)
        }

        let host = settings.hosts.first!
        let client: DNSClient
        
        if let dnsServer = settings.dnsServer {
            client = try await DNSClient(servers: [SocketAddress(ipAddress: dnsServer, port: 53)])
        } else {
            client = try await DNSClient()
        }
        
        var settings = settings
        settings.hosts = try await resolveSRV(host, on: client)
        return try await run(settings, client)
    }

    private static let prefix = "_mongodb._tcp."
    private static func resolveSRV(_ host: ConnectionSettings.Host, on client: DNSClient) async throws -> [ConnectionSettings.Host] {
        return try await client.getSRVRecords(from: prefix + host.hostname).get().map { record in
            return ConnectionSettings.Host(hostname: record.resource.domainName.string, port: host.port)
        }
    }
    
    #if canImport(NIOTransportServices) && os(iOS)
    let group = NIOTSEventLoopGroup(loopCount: 1)
    #else
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    #endif

    private func makeConnection(to host: ConnectionSettings.Host) async throws -> PooledConnection {
        if isClosed {
            throw MongoError(.cannotConnect, reason: .connectionClosed)
        }

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
            connection.slaveOk = self.slaveOk

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
            logger.error("Connection to \(host) disconnected with error \(error)")
            
            self.timeoutHosts.insert(host)
            self.discoveredHosts.remove(host)
            throw error
        }
    }

    /// Checks all known hosts for isMaster and writability
    private func rediscover() async {
        if isClosed {
            logger.info("Rediscovering, but the server is disconnected")
            return
        }

        self.wireVersion = nil

        for pooledConnection in pool {
            let connection = pooledConnection.connection
            
            do {
                let handshake = try await connection.doHandshake(
                    clientDetails: nil,
                    credentials: settings.authentication
                )
                
                self.updateSDAM(from: handshake)
            } catch {
                await self.remove(connection: connection, error: error)
            }
        }
        
        self.timeoutHosts = []
        self.completedInitialDiscovery = true
    }

    private func remove(connection: MongoConnection, error: Error) async {
        if let index = self.pool.firstIndex(where: { $0.connection === connection }) {
            let pooledConnection = self.pool[index]
            self.pool.remove(at: index)
            self.discoveredHosts.remove(pooledConnection.host)
            await pooledConnection.connection.context.cancelQueries(error)
        }
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
    
    private func makeConnectionRecursively(for request: MongoConnectionPoolRequest, attempts: Int = 3) async throws -> MongoConnection {
        var attempts = attempts
        while true {
            do {
                return try await self._getConnection(writable: request.writable)
            } catch {
                attempts -= 1
                
                if attempts < 0 {
                    throw error
                }
            }
        }
    }

    public func next(for request: MongoConnectionPoolRequest) async throws -> MongoConnection {
        return try await self.makeConnectionRecursively(for: request)
    }

    private func _getConnection(writable: Bool = true, emptyPoolError: Error? = nil) async throws -> MongoConnection {
        if let matchingConnection = await findMatchingExistingConnection(writable: writable) {
            return matchingConnection.connection
        }

        guard let host = undiscoveredHosts.first else {
            await self.rediscover()
            guard let match = await findMatchingExistingConnection(writable: writable) else {
                self.logger.error("Couldn't find or create a connection to MongoDB with the requested specification")
                throw emptyPoolError ?? MongoError(.cannotConnect, reason: .noAvailableHosts)
            }

            return match.connection
        }

        logger.info("No matching connection found with host: \(host) - creating new connection")
        let pooledConnection = try await makeConnection(to: host)
        self.pool.append(pooledConnection)

        guard let handshake = await pooledConnection.connection.serverHandshake else {
            throw MongoError(.cannotConnect, reason: .handshakeFailed)
        }

        let unwritable = writable && handshake.readOnly == true
        let unreadable = !self.slaveOk && !handshake.ismaster

        if unwritable || unreadable {
            return try await self._getConnection(writable: writable)
        } else {
            return pooledConnection.connection
        }
    }

    /// Closes all connections
    public func disconnect() async {
        logger.debug("Disconnecting MongoDB Cluster")
        self.wireVersion = nil
        self.isClosed = true
        let connections = self.pool
        self.pool = []
        self.discoveredHosts = []

        for pooledConnection in connections {
            await pooledConnection.connection.close()
        }
    }

    /// Prompts MongoKitten to connect to the remote again
    public func reconnect() async throws {
        logger.debug("Reconnecting to MongoDB Cluster")
        await disconnect()
        self.isClosed = false
        self.completedInitialDiscovery = false
        _ = try await self.next(for: MongoConnectionPoolRequest(writable: true))
        await rediscover()
    }
}

fileprivate struct PooledConnection {
    let host: ConnectionSettings.Host
    let connection: MongoConnection
}
