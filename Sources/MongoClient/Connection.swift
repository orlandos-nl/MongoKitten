import BSON
import Foundation
import MongoCore
import NIO
import Logging
import Metrics

#if canImport(NIOTransportServices) && os(iOS)
import Network
import NIOTransportServices
#else
import NIOSSL
#endif

public struct MongoHandshakeResult {
    public let sent: Date
    public let received: Date
    public let handshake: Result<ServerHandshake, Error>
    public var interval: Double {
        received.timeIntervalSince(sent)
    }
    
    init(sentAt sent: Date, handshake: Result<ServerHandshake, Error>) {
        self.sent = sent
        self.received = Date()
        self.handshake = handshake
    }
}

public final class MongoConnection {
    /// The NIO channel
    private let channel: Channel
    public var logger: Logger { context.logger }
    var queryTimer: Metrics.Timer?
    public internal(set) var lastHeartbeat: MongoHandshakeResult?
    public var queryTimeout: TimeAmount = .seconds(30)
    
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
    public var implicitSession: MongoClientSession {
        return sessionManager.makeImplicitClientSession()
    }
    public var implicitSessionId: SessionIdentifier {
        return implicitSession.sessionId
    }

    /// The current request ID, used to generate unique identifiers for MongoDB commands
    private var currentRequestId: Int32 = 0
    internal let context: MongoClientContext
    public var serverHandshake: ServerHandshake? {
        return context.serverHandshake
    }

    public var closeFuture: EventLoopFuture<Void> {
        return channel.closeFuture
    }

    public var eventLoop: EventLoop { return channel.eventLoop }
    public var allocator: ByteBufferAllocator { return channel.allocator }

    public var slaveOk = false

    internal func nextRequestId() -> Int32 {
        defer { currentRequestId = currentRequestId &+ 1 }

        return currentRequestId
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
        on eventLoop: EventLoop,
        logger: Logger = .defaultMongoCore,
        resolver: Resolver? = nil,
        clientDetails: MongoClientDetails? = nil,
        sessionManager: MongoSessionManager = .init()
    ) -> EventLoopFuture<MongoConnection> {
        let context = MongoClientContext(logger: logger)

        #if canImport(NIOTransportServices) && os(iOS)
        var bootstrap = NIOTSConnectionBootstrap(group: eventLoop)

        if settings.useSSL {
            bootstrap = bootstrap.tlsOptions(NWProtocolTLS.Options())
        }
        #else
        let bootstrap = ClientBootstrap(group: eventLoop)
            .resolver(resolver)
        #endif

        guard let host = settings.hosts.first else {
            logger.critical("Cannot connect to MongoDB: No host specified")
            return eventLoop.makeFailedFuture(MongoError(.cannotConnect, reason: .noHostSpecified))
        }

        return bootstrap
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                #if !canImport(NIOTransportServices)
                if settings.useSSL {
                    do {
                        var configuration = TLSConfiguration.clientDefault
                        
                        if let caCertPath = settings.sslCaCertificatePath {
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
            }.connect(host: host.hostname, port: host.port).flatMap { channel in
                let connection = MongoConnection(
                    channel: channel,
                    context: context,
                    sessionManager: sessionManager
                )

                return connection.authenticate(
                    clientDetails: clientDetails,
                    using: settings.authentication,
                    to: settings.authenticationSource ?? "admin"
                ).map { connection}
        }
    }

    /// Executes a MongoDB `isMaster`
    ///
    /// - SeeAlso: https://github.com/mongodb/specifications/blob/master/source/mongodb-handshake/handshake.rst
    public func doHandshake(
        clientDetails: MongoClientDetails?,
        credentials: ConnectionSettings.Authentication,
        authenticationDatabase: String = "admin"
    ) -> EventLoopFuture<ServerHandshake> {
        let userNamespace: String?

        if case .auto(let user, _) = credentials {
            userNamespace = "\(authenticationDatabase).\(user)"
        } else {
            userNamespace = nil
        }
            
        // NO session must be used here: https://github.com/mongodb/specifications/blob/master/source/sessions/driver-sessions.rst#when-opening-and-authenticating-a-connection
        // Forced on the current connection
        let sent = Date()
        let result = self.executeCodable(
            IsMaster(
                clientDetails: clientDetails,
                userNamespace: userNamespace
            ),
            namespace: .administrativeCommand,
            sessionId: nil
        ).flatMapThrowing { try ServerHandshake(reply: $0) }
        
        result.whenComplete { result in
            self.lastHeartbeat = MongoHandshakeResult(sentAt: sent, handshake: result)
        }
        
        return result
    }

    public func authenticate(
        clientDetails: MongoClientDetails?,
        using credentials: ConnectionSettings.Authentication,
        to authenticationDatabase: String = "admin"
    ) -> EventLoopFuture<Void> {
        return doHandshake(
            clientDetails: clientDetails,
            credentials: credentials,
            authenticationDatabase: authenticationDatabase
        ).flatMap { handshake in
            self.context.serverHandshake = handshake
            return self.authenticate(to: authenticationDatabase, with: credentials)
        }
    }

    func executeMessage<Request: MongoRequestMessage>(_ message: Request) -> EventLoopFuture<MongoServerReply> {
        if context.didError {
            return self.close().flatMap {
                return self.eventLoop.makeFailedFuture(MongoError(.queryFailure, reason: .connectionClosed))
            }
        }
        
        let promise = eventLoop.makePromise(of: MongoServerReply.self)
        context.awaitReply(toRequestId: message.header.requestId, completing: promise)
        
        eventLoop.scheduleTask(in: queryTimeout) {
            let error = MongoError(.queryTimeout, reason: nil)
            self.context.failQuery(byRequestId: message.header.requestId, error: error)
        }

        var buffer = channel.allocator.buffer(capacity: 4_096)
        message.write(to: &buffer)
        return channel.writeAndFlush(buffer).flatMap { promise.futureResult }
    }

    public func close() -> EventLoopFuture<Void> {
        return self.channel.close()
    }

    deinit {
        _ = close()
    }
}
