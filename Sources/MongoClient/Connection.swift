import BSON
import MongoCore
import NIO
import NIOSSL

public final class MongoConnection {
    /// The NIO channel
    private let channel: Channel

    /// A LIFO (Last In, First Out) holder for sessions
    private let sessionManager: MongoSessionManager

    /// The current request ID, used to generate unique identifiers for MongoDB commands
    private var currentRequestId: Int32 = 0
    internal let context: MongoClientContext
    public var serverHandshake: ServerHandshake? {
        return context.serverHandshake
    }

    public var closeFuture: EventLoopFuture<Void> {
        return channel.closeFuture
    }

    public var eventLoop: EventLoop { channel.eventLoop }
    public var allocator: ByteBufferAllocator { channel.allocator }

    public var slaveOk = false

    internal func nextRequestId() -> Int32 {
        defer { currentRequestId = currentRequestId &+ 1 }

        return currentRequestId
    }

    /// Creates a connection that can communicate with MongoDB over a channel.
    ///
    public init(channel: Channel, context: MongoClientContext) {
        self.channel = channel
        self.context = context
        self.sessionManager = MongoSessionManager()
    }

    public static func addHandlers(to channel: Channel, context: MongoClientContext) -> EventLoopFuture<Void> {
        let parser = ClientConnectionParser(context: context)
        return channel.pipeline.addHandler(ByteToMessageHandler(parser))
    }

    public static func connect(
        settings: ConnectionSettings,
        on eventLoop: EventLoop,
        resolver: Resolver? = nil,
        clientDetails: MongoClientDetails? = nil
    ) -> EventLoopFuture<MongoConnection> {
        let context = MongoClientContext()

        #if canImport(NIOTransportServices)
        var bootstrap = NIOTSConnectionBootstrap(group: cluster.group)

        if cluster.settings.useSSL {
            bootstrap = bootstrap.tlsOptions(NWProtocolTLS.Options())
        }
        #else
        let bootstrap = ClientBootstrap(group: eventLoop)
        #endif

        guard let host = settings.hosts.first else {
            return eventLoop.makeFailedFuture(MongoError(.cannotConnect, reason: .noHostSpecified))
        }

        return bootstrap
            .resolver(resolver)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                #if !canImport(NIOTransportServices)
                if settings.useSSL {
                    do {
                        let handler = try NIOSSLClientHandler(context: NIOSSLContext(configuration: .clientDefault), serverHostname: host.hostname)
                        return
                            channel.pipeline.addHandler(handler).flatMap {
                            return MongoConnection.addHandlers(to: channel, context: context)
                        }
                    } catch {
                        return channel.eventLoop.makeFailedFuture(error)
                    }
                }
                #endif
                
                return MongoConnection.addHandlers(to: channel, context: context)
            }.connect(host: host.hostname, port: host.port).flatMap { channel in
                let connection = MongoConnection(channel: channel, context: context)

                return connection.authenticate(clientDetails: clientDetails, using: settings.authentication).map { connection}
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
        return self.executeCodable(
            IsMaster(
                clientDetails: clientDetails,
                userNamespace: userNamespace
            ),
            namespace: .administrativeCommand
        ).flatMapThrowing { try ServerHandshake(reply: $0) }
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
        let promise = eventLoop.makePromise(of: MongoServerReply.self)
        context.awaitReply(toRequestId: message.header.requestId, completing: promise)

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
