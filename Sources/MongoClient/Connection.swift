import BSON
import Foundation
import MongoCore
import NIO
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

public struct MongoHandshakeResult {
    public let sent: Date
    public let received: Date
    public let handshake: ServerHandshake
    public var interval: Double {
        received.timeIntervalSince(sent)
    }
    
    init(sentAt sent: Date, handshake: ServerHandshake) {
        self.sent = sent
        self.received = Date()
        self.handshake = handshake
    }
}

public final actor MongoConnection: @unchecked Sendable {
    /// The NIO channel
    internal let channel: Channel
    public nonisolated var logger: Logger { context.logger }
    var queryTimer: Metrics.Timer?
    public internal(set) var lastHeartbeat: MongoHandshakeResult?
    public var queryTimeout: TimeAmount? = .seconds(30)
    
    public var isMetricsEnabled = false {
        didSet {
            if isMetricsEnabled, !oldValue {
                queryTimer = Metrics.Timer(label: "org.openkitten.mongokitten.core.queries")
            } else {
                queryTimer = nil
            }
        }
    }
    
    /// A LIFO (Last In, First Out) holder for sessions
    public let sessionManager: MongoSessionManager
    public nonisolated var implicitSession: MongoClientSession {
        return sessionManager.implicitClientSession
    }
    public nonisolated var implicitSessionId: SessionIdentifier {
        return implicitSession.sessionId
    }
    
    /// The current request ID, used to generate unique identifiers for MongoDB commands
    private var currentRequestId = ManagedAtomic<Int32>(0)
    internal let context: MongoClientContext
    public var serverHandshake: ServerHandshake? {
        get async { await context.serverHandshake }
    }
    
    public nonisolated var closeFuture: EventLoopFuture<Void> {
        return channel.closeFuture
    }
    
    public nonisolated var eventLoop: EventLoop { return channel.eventLoop }
    public var allocator: ByteBufferAllocator { return channel.allocator }
    
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
    
    public static func addHandlers(to channel: Channel, context: MongoClientContext) -> EventLoopFuture<Void> {
        let parser = ClientConnectionParser(context: context)
        return channel.pipeline.addHandler(ByteToMessageHandler(parser))
    }
    
    public static func connect(
        settings: ConnectionSettings,
        logger: Logger = Logger(label: "org.openkitten.mongokitten.connection"),
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
        logger: Logger = Logger(label: "org.openkitten.mongokitten.connection"),
        onGroup group: _MongoPlatformEventLoopGroup,
        resolver: Resolver? = nil,
        clientDetails: MongoClientDetails? = nil,
        sessionManager: MongoSessionManager = .init()
    ) async throws -> MongoConnection {
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
        
        guard let host = settings.hosts.first else {
            logger.critical("Cannot connect to MongoDB: No host specified")
            throw MongoError(.cannotConnect, reason: .noHostSpecified)
        }
        
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
            sessionId: nil
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
    
    func executeMessage<Request: MongoRequestMessage>(_ message: Request) async throws -> MongoServerReply {
        if await self.context.didError {
            channel.close(mode: .all, promise: nil)
            throw MongoError(.queryFailure, reason: .connectionClosed)
        }
        
        let promise = self.eventLoop.makePromise(of: MongoServerReply.self)
        await self.context.setReplyCallback(forRequestId: message.header.requestId, completing: promise)
        
        var buffer = self.channel.allocator.buffer(capacity: Int(message.header.messageLength))
        message.write(to: &buffer)
        try await self.channel.writeAndFlush(buffer)
        
        if let queryTimeout = queryTimeout {
            Task {
                try await Task.sleep(nanoseconds: UInt64(queryTimeout.nanoseconds))
                promise.fail(MongoError(.queryTimeout, reason: nil))
            }
        }
        
        return try await promise.futureResult.get()
    }
    
    public func close() async {
        _ = try? await self.channel.close()
    }
    
    deinit {
        channel.close(mode: .all, promise: nil)
    }
}
