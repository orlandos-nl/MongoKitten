import BSON
import Tracing
import Foundation
import MongoCore
import NIO
import ServiceContextModule
import Atomics
import Logging
import Metrics
import NIOConcurrencyHelpers

#if canImport(NIOTransportServices) && os(iOS)
import Network
import NIOTransportServices
#else
import NIOSSL
#endif

/// The result of a handshake, containing the handshake and the time it took to receive the reply.
public struct MongoHandshakeResult {
    /// The time the handshake was sent
    public let sent: Date

    /// The time the handshake was received
    public let received: Date

    /// The handshake
    public let handshake: ServerHandshake

    /// The time it took to receive the handshake
    public var interval: Double {
        received.timeIntervalSince(sent)
    }

    init(sentAt sent: Date, handshake: ServerHandshake) {
        self.sent = sent
        self.received = Date()
        self.handshake = handshake
    }
}

/// A connection to a MongoDB server.
public final actor MongoConnection: Sendable {
    /// The NIO channel used for communication
    internal let channel: Channel
    public nonisolated var logger: Logger { context.logger }

    var queryTimer: Metrics.Timer?

    /// The last heartbeat result received
    public internal(set) var lastHeartbeat: MongoHandshakeResult?

    /// The timeout for queries, defaults to 30 seconds
    public var queryTimeout: TimeAmount? = .seconds(30)

    internal var lastServerActivity: Date?

    /// Whether metrics are enabled. When enabled, metrics will be collected for queries using the `Metrics` library.
    public var isMetricsEnabled = false {
        didSet {
            if isMetricsEnabled, !oldValue {
                queryTimer = Metrics.Timer(label: "org.orlandos-nl.mongokitten.core.queries")
            } else {
                queryTimer = nil
            }
        }
    }

    /// A LIFO (Last In, First Out) holder for sessions
    public let sessionManager: MongoSessionManager

    /// The implicit session, used for operations that don't require a session
    public nonisolated var implicitSession: MongoClientSession {
        return sessionManager.implicitClientSession
    }

    /// The implicit session ID, used for operations that don't require a session
    public nonisolated var implicitSessionId: SessionIdentifier {
        return implicitSession.sessionId
    }

    /// The current request ID, used to generate unique identifiers for MongoDB commands
    private var currentRequestId = ManagedAtomic<Int32>(0)
    internal let context: MongoClientContext

    /// The handshake received from the server
    public var serverHandshake: ServerHandshake? {
        get async { await context.serverHandshake }
    }

    public nonisolated var closeFuture: EventLoopFuture<Void> {
        return channel.closeFuture
    }

    public nonisolated var eventLoop: EventLoop { return channel.eventLoop }
    public var allocator: ByteBufferAllocator { return channel.allocator }

    /// Whether this connection is a slaveOk connection, meaning it can read from secondaries
    public let slaveOk = ManagedAtomic(false)

    internal func nextRequestId() -> Int32 {
        return currentRequestId.loadThenWrappingIncrement(ordering: .relaxed)
    }

    /// Creates a connection that can communicate with MongoDB over a channel
    public init(channel: Channel, context: MongoClientContext, sessionManager: MongoSessionManager = .init()) {
        self.sessionManager = sessionManager
        self.channel = channel
        self.context = context
    }

    /// Registers MongoKitten's handlers on the channel
    public static func addHandlers(to channel: Channel, context: MongoClientContext) -> EventLoopFuture<Void> {
        let parser = ClientConnectionParser(context: context)
        return channel.pipeline.addHandler(ByteToMessageHandler(parser))
    }

    public func ping() async throws {
        _ = try await executeCodable(
            [ "ping": 1 ],
            decodeAs: OK.self,
            namespace: .administrativeCommand,
            sessionId: implicitSessionId
        )
    }

    /// Connects to a MongoDB server using the given settings.
    ///
    ///     let connection = try await MongoConnection.connect(to: ConnectionSettings("mongodb://localhost:27017"))
    ///
    /// - Parameters:
    /// - settings: The settings to use for connecting
    /// - logger: The logger to use for logging
    /// - resolver: The resolver to use for resolving hostnames
    /// - clientDetails: The client details to use for the handshake
    /// - Returns: A connection to the MongoDB server
    public static func connect(
        settings: ConnectionSettings,
        logger: Logger = Logger(label: "org.orlandos-nl.mongokitten.connection"),
        resolver: Resolver? = nil,
        clientDetails: MongoClientDetails? = nil
    ) async throws -> MongoConnection {
#if canImport(NIOTransportServices) && os(iOS)
        return try await connect(settings: settings, logger: logger, onGroup: NIOTSEventLoopGroup(loopCount: 1), resolver: resolver, clientDetails: clientDetails)
#else
        return try await connect(settings: settings, logger: logger, onGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1), resolver: resolver, clientDetails: clientDetails)
#endif
    }

    internal static func connect(
        settings: ConnectionSettings,
        logger: Logger = Logger(label: "org.orlandos-nl.mongokitten.connection"),
        onGroup group: _MongoPlatformEventLoopGroup,
        resolver: Resolver? = nil,
        clientDetails: MongoClientDetails? = nil,
        sessionManager: MongoSessionManager = .init()
    ) async throws -> MongoConnection {
        guard let host = settings.hosts.first else {
            logger.critical("Cannot connect to MongoDB: No host specified")
            throw MongoError(.cannotConnect, reason: .noHostSpecified)
        }

        if settings.hosts.count > 1 {
            logger.warning("Attempt to connect to multiple hosts using MongoConnection. Only the first connection will be used. Please use MongoCluster instead.")
        }

        var logger = logger
        logger[metadataKey: "mongo-host"] = .string(host.hostname)
        logger[metadataKey: "mongo-port"] = .string(String(host.port))

        let context = MongoClientContext(logger: logger)

#if canImport(NIOTransportServices) && os(iOS)
        var bootstrap = NIOTSConnectionBootstrap(group: group)

        if settings.useSSL {
            bootstrap = bootstrap.tlsOptions(NWProtocolTLS.Options())
        }
#else
        let bootstrap = ClientBootstrap(group: group)
            .resolver(resolver)
#endif

        let channel = try await bootstrap
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
#if canImport(NIOTransportServices) && os(iOS)
#else
                if settings.useSSL {
                    do {
                        var configuration = TLSConfiguration.clientDefault

                        if let caCert = settings.sslCaCertificate {
                            configuration.trustRoots = NIOSSLTrustRoots.certificates([caCert])
                        } else if let caCertPath = settings.sslCaCertificatePath {
                            configuration.trustRoots = NIOSSLTrustRoots.file(caCertPath)
                        }

                        let handler = try NIOSSLClientHandler(context: NIOSSLContext(configuration: configuration), serverHostname: host.hostname)
                        return channel.pipeline.addHandler(handler).flatMap {
                            return MongoConnection.addHandlers(to: channel, context: context)
                        }
                    } catch {
                        return channel.eventLoop.makeFailedFuture(error)
                    }
                }
#endif

                return MongoConnection.addHandlers(to: channel, context: context)
            }.connect(host: host.hostname, port: host.port).get()

        let connection = MongoConnection(
            channel: channel,
            context: context,
            sessionManager: sessionManager
        )

        try await connection.authenticate(
            clientDetails: clientDetails,
            using: settings.authentication,
            to: settings.authenticationSource ?? "admin"
        )

        return connection
    }

    /// Executes a MongoDB `isMaster`
    ///
    /// - SeeAlso: https://github.com/mongodb/specifications/blob/master/source/mongodb-handshake/handshake.rst
    public func doHandshake(
        clientDetails: MongoClientDetails?,
        credentials: ConnectionSettings.Authentication,
        authenticationDatabase: String = "admin"
    ) async throws -> ServerHandshake {
        let userNamespace: String?

        if case .auto(let user, _) = credentials {
            userNamespace = "\(authenticationDatabase).\(user)"
        } else {
            userNamespace = nil
        }

        // NO session must be used here: https://github.com/mongodb/specifications/blob/master/source/sessions/driver-sessions.rst#when-opening-and-authenticating-a-connection
        // Forced on the current connection
        let sent = Date()

        let result = try await executeCodable(
            IsMaster(
                clientDetails: clientDetails,
                userNamespace: userNamespace
            ),
            decodeAs: ServerHandshake.self,
            namespace: .administrativeCommand,
            sessionId: nil,
            traceLabel: "Handshake"
        )

        await context.setServerHandshake(to: result)
        self.lastHeartbeat = MongoHandshakeResult(sentAt: sent, handshake: result)
        return result
    }

    // `@inline(never)` needed due to the llvm coroutine splitting issue
    // `https://github.com/apple/swift/issues/60380`.
    @inline(never)
    public func authenticate(
        clientDetails: MongoClientDetails?,
        using credentials: ConnectionSettings.Authentication,
        to authenticationDatabase: String = "admin"
    ) async throws {
        let handshake = try await doHandshake(
            clientDetails: clientDetails,
            credentials: credentials,
            authenticationDatabase: authenticationDatabase
        )

        await self.context.setServerHandshake(to: handshake)
        try await self.authenticate(to: authenticationDatabase, serverHandshake: handshake, with: credentials)
    }

    @Sendable nonisolated func _withSpan<T: Sendable>(
        _ label: String,
        context: ServiceContext? = nil,
        ofKind kind: SpanKind,
        perform: @Sendable (ServiceContext) async throws -> T
    ) async throws -> T {
        let context = context ?? .current ?? .topLevel

#if swift(<5.10)
        return try await withSpan(
            label,
            context: context,
            ofKind: kind
        ) { _ in
            try await perform(context)
        }
#else
        return try await perform(context)
#endif
    }

    func executeMessage<Request: MongoRequestMessage>(
        _ message: Request,
        logMetadata: Logger.Metadata? = nil,
        traceLabel: String,
        serviceContext context: ServiceContext? = nil
    ) async throws -> MongoServerReply {
        if await self.context.didError {
            logger.info("Query could not be executed on this connection because an error occurred", metadata: logMetadata)
            channel.close(mode: .all, promise: nil)
            throw MongoError(.queryFailure, reason: .connectionClosed)
        }

        let promise = self.eventLoop.makePromise(of: MongoServerReply.self)
        await self.context.setReplyCallback(forRequestId: message.header.requestId, completing: promise)

        return try await _withSpan(
            "MongoKitten.\(traceLabel)",
            context: context,
            ofKind: .client
        ) { [queryTimeout] _ in
            var buffer = self.channel.allocator.buffer(capacity: Int(message.header.messageLength))
            message.write(to: &buffer)
            try await self.channel.writeAndFlush(buffer)

            return try await withThrowingTaskGroup(of: MongoServerReply.self) { taskGroup in
                if let queryTimeout {
                    taskGroup.addTask {
                        try await Task.sleep(nanoseconds: UInt64(queryTimeout.nanoseconds))
                        let error = MongoError(.queryTimeout, reason: nil)
                        promise.fail(error)
                        throw error
                    }
                }

                let result = try await promise.futureResult.get()
                taskGroup.cancelAll()
                await self.logActivity()
                return result
            }
        }
    }

    private func logActivity() {
        self.lastServerActivity = Date()
    }

    /// Close the connection to the MongoDB server
    public func close() async {
        _ = try? await self.channel.close()
    }

    deinit {
        channel.close(mode: .all, promise: nil)
    }
}
