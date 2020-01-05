import BSON
import NIO

#if canImport(NIOTransportServices)
    import NIOTransportServices
    import Network
    public typealias _MKNIOEventLoopRequirement = NIOTSEventLoopGroup
#else
    public typealias _MKNIOEventLoopRequirement = EventLoopGroup
    #if canImport(NIOOpenSSL)
        import NIOOpenSSL
    #endif
#endif

#if canImport(_MongoKittenCrypto)
    import _MongoKittenCrypto
#endif

import Foundation

// TODO: https://github.com/mongodb/specifications/tree/master/source/retryable-writes

/// A single MongoDB connection to a single MongoDB server.
/// `Connection` handles the lowest level communication to a MongoDB instance.
///
/// `Connection` is not threadsafe. It is bound to a single NIO EventLoop.
internal final class Connection {
    deinit {
        _ = channel.close(mode: .all)
    }
    
    /// The NIO Client Connection Context
    let context: ClientQueryContext
    
    /// The NIO channel
    let channel: Channel
    
    let sessionManager: SessionManager
    var implicitSession: ClientSession
    
    /// The connection settings for this connection
    private(set) var settings: ConnectionSettings
    
    /// The result of the `isMaster` handshake with the server
    private(set) var handshakeResult: ConnectionHandshakeReply? = nil {
        didSet {
            if let handshakeResult = handshakeResult {
                clientConnectionSerializer.includeSession = handshakeResult.maxWireVersion.supportsSessions
            }
        }
    }
    
    /// The current request ID, used to generate unique identifiers for MongoDB commands
    private var currentRequestId: Int32 = 0
    
    private let clientConnectionSerializer: ClientConnectionSerializer
    
    // TODO: var retryWrites = false
    
    /// If `true`, allows reading from this node if it's a slave node
    var slaveOk: Bool {
        get {
            return clientConnectionSerializer.slaveOk
        }
        set {
            clientConnectionSerializer.slaveOk = newValue
        }
    }
    
    /// Closes the connection to MongoDB
    func close() -> EventLoopFuture<Void> {
        self.context.isClosed = true
        
        return self.channel.close()
    }
    
    /// The eventLoop this connection lives on
    var eventLoop: EventLoop {
        return channel.eventLoop
    }
    
    internal static func connect(
        for cluster: Cluster,
        host: ConnectionSettings.Host
    ) -> EventLoopFuture<Connection> {
        let context = ClientQueryContext()
        let serializer = ClientConnectionSerializer(context: context)
        
        #if canImport(NIOTransportServices)
        var bootstrap = NIOTSConnectionBootstrap(group: cluster.group)
        
        if cluster.settings.ssl.useSSL {
            bootstrap = bootstrap.tlsOptions(NWProtocolTLS.Options())
        }
        #else
        let bootstrap = ClientBootstrap(group: cluster.eventLoop)
        #endif
        
        return bootstrap// Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return Connection.initialize(
                    pipeline: channel.pipeline,
                    group: cluster.group,
                    hostname: host.hostname,
                    context: context,
                    settings: cluster.settings,
                    serializer: serializer
                )
            }.connect(host: host.hostname, port: Int(host.port)).then { channel in
                let connection = Connection(
                    channel: channel,
                    context: context,
                    implicitSession: cluster.sessionManager.makeImplicitSession(for: cluster),
                    sessionManager: cluster.sessionManager,
                    settings: cluster.settings,
                    serializer: serializer
                )
                
                return connection.executeHandshake(withClientMetadata: true)
                    .then { connection.authenticate() }
                    .map { connection }
            }
    }
    
    init(channel: Channel, context: ClientQueryContext, implicitSession: ClientSession, sessionManager: SessionManager, settings: ConnectionSettings, serializer: ClientConnectionSerializer) {
        self.channel = channel
        self.context = context
        self.sessionManager = sessionManager
        self.settings = settings
        self.clientConnectionSerializer = serializer
        self.implicitSession = implicitSession
    }
    
    static func initializeMobile(pipeline: ChannelPipeline, group: PlatformEventLoopGroup, context: ClientQueryContext, serializer: ClientConnectionSerializer, dbPath: String) -> EventLoopFuture<Void>  {
        #if canImport(mongo_mobile)
        let config = MongoConfiguration(storage: .init(dbPath: dbPath))
        let tcp = MobileWriter(pipeline: pipeline)
        
        return pipeline.addHandlers([ClientConnectionParser(context: context), serializer, tcp])
        #else
        fatalError("MongoKitten Mobile unsupported for this platform/configuration")
        #endif
    }
    
    static func initialize(pipeline: ChannelPipeline, group: PlatformEventLoopGroup, hostname: String?, context: ClientQueryContext, settings: ConnectionSettings, serializer: ClientConnectionSerializer) -> EventLoopFuture<Void> {
        let promise: EventLoopPromise<Void> = pipeline.eventLoop.newPromise()
        
        var handlers: [ChannelHandler] = [ClientConnectionParser(context: context), serializer]
        
        #if canImport(NIOOpenSSL)
        
        let sslConfiguration: TLSConfiguration?
        switch settings.ssl {
        case .none:
            sslConfiguration = nil
        case .ssl:
            sslConfiguration = TLSConfiguration.forClient(
                certificateVerification: settings.verifySSLCertificates ? .fullVerification : .none
            )
        case .sslCA(let path):
            sslConfiguration = TLSConfiguration.forClient(certificateVerification: .fullVerification, trustRoots: .file(path))
        }
        
        if let sslConfiguration = sslConfiguration {
            do {
                let sslContext = try SSLContext(configuration: sslConfiguration)
                let sslHandler = try OpenSSLClientHandler(context: sslContext, serverHostname: hostname)
                
                handlers.insert(sslHandler, at: 0)
            } catch {
                promise.fail(error: error)
                return promise.futureResult
            }
        }
        #elseif !canImport(NIOTransportServices)
        if settings.ssl.useSSL {
            promise.fail(error: MongoKittenError(.unableToConnect, reason: .sslNotAvailable))
        }
        #endif
        
        func addNext() {
            guard handlers.count > 0 else {
                promise.succeed(result: ())
                return
            }
            
            let handler = handlers.removeFirst()
            
            pipeline.add(handler: handler).whenSuccess {
                addNext()
            }
        }
        
        addNext()
        
        return promise.futureResult
    }
    
    func _execute<C: AnyMongoDBCommand>(command: C, session: ClientSession?, transaction: TransactionQueryOptions?) -> EventLoopFuture<ServerReply> {
        if self.context.isClosed {
            return self.eventLoop.newFailedFuture(error: MongoKittenError(.commandFailure, reason: .connectionClosed))
        }
        
        do {
            if let handshakeResult = self.handshakeResult {
                try command.checkValidity(for: handshakeResult.maxWireVersion)
            }
        } catch {
            return self.eventLoop.newFailedFuture(error: error)
        }
        
        let promise: EventLoopPromise<ServerReply> = self.channel.eventLoop.newPromise()
        let command = MongoDBCommandContext(
            command: command,
            requestID: nextRequestId(),
            retry: true, // TODO: This is not correct, and a difference between read/write
            session: session,
            transaction: transaction,
            promise: promise
        )
        
        self.context.queries.append(command)
        
        _ = self.channel.writeAndFlush(command)
        return promise.futureResult
    }
    
    public func nextRequestId() -> Int32 {
        defer { currentRequestId = currentRequestId &+ 1 }
        
        return currentRequestId
    }
    
    private func authenticate() -> EventLoopFuture<Void> {
        let source = settings.authenticationSource ?? settings.targetDatabase ?? "admin"
        let namespace = Namespace(to: "$cmd", inDatabase: source)
        
        switch settings.authentication {
        case .unauthenticated:
            return eventLoop.newSucceededFuture(result: ())
        case .auto(let username, let password):
            if let mechanisms = handshakeResult!.saslSupportedMechs {
                nextMechanism: for mechanism in mechanisms {
                    switch mechanism {
                    case "SCRAM-SHA-1":
                        return self.authenticateSASL(hasher: SHA1(), namespace: namespace, username: username, password: password)
                    case "SCRAM-SHA-256":
                        return self.authenticateSASL(hasher: SHA256(), namespace: namespace, username: username, password: password)
                    default:
                        continue nextMechanism
                    }
                }
                
                return eventLoop.newFailedFuture(error: MongoKittenError(.authenticationFailure, reason: .unsupportedAuthenticationMechanism))
            } else if handshakeResult!.maxWireVersion.supportsScramSha1 {
                return self.authenticateSASL(hasher: SHA1(), namespace: namespace, username: username, password: password)
            } else {
                return self.authenticateCR(username, password: password, namespace: namespace)
            }
        case .scramSha1(let username, let password):
            return self.authenticateSASL(hasher: SHA1(), namespace: namespace, username: username, password: password)
        case .scramSha256(let username, let password):
            return self.authenticateSASL(hasher: SHA256(), namespace: namespace, username: username, password: password)
        case .mongoDBCR(let username, let password):
            return self.authenticateCR(username, password: password, namespace: namespace)
        }
    }
    
    func executeHandshake(withClientMetadata: Bool) -> EventLoopFuture<Void> {
        // Construct app details
        let app: ConnectionHandshakeCommand.ClientDetails.ApplicationDetails?
        if let appName = settings.applicationName {
            app = .init(name: appName)
        } else {
            app = nil
        }
        
        let commandCollection = self.implicitSession.pool["admin"]["$cmd"]
        
        let userNamespace: String?
        
        if case .auto(let user, _) = settings.authentication {
            let authDB = settings.targetDatabase ?? "admin"
            userNamespace = "\(authDB).\(user)"
        } else {
            userNamespace = nil
        }
        
        // NO session must be used here: https://github.com/mongodb/specifications/blob/master/source/sessions/driver-sessions.rst#when-opening-and-authenticating-a-connection
        // Forced on the current connection
        return self._execute(command: ConnectionHandshakeCommand(
            clientDetails: withClientMetadata ? ConnectionHandshakeCommand.ClientDetails(application: app) : nil,
            userNamespace: userNamespace,
            collection: commandCollection
        ), session: nil, transaction: nil).thenThrowing { serverReply in
            let reply = try BSONDecoder().decode(
                ConnectionHandshakeCommand.Reply.self,
                from: try serverReply.documents.assertFirst()
            )
            
            self.handshakeResult = reply
            
            algorithmSelection: if
                case .auto(let user, let pass) = self.settings.authentication,
                let saslSupportedMechs = reply.saslSupportedMechs
            {
                var selectedAlgorithm: ConnectionSettings.Authentication?
                
                nextMechanism: for mech in saslSupportedMechs {
                    switch mech {
                    case "SCRAM-SHA-256":
                        selectedAlgorithm = .scramSha256(username: user, password: pass)
                        break algorithmSelection
                    case "SCRAM-SHA-1":
                        selectedAlgorithm = .scramSha1(username: user, password: pass)
                    default:
                        // Unknown algorithm
                        continue nextMechanism
                    }
                }
                
                if let selectedAlgorithm = selectedAlgorithm {
                    self.settings.authentication = selectedAlgorithm
                } else if reply.maxWireVersion.supportsScramSha1 {
                    self.settings.authentication = .mongoDBCR(username: user, password: pass)
                } else {
                    self.settings.authentication = .scramSha1(username: user, password: pass)
                }
            }
            
            self.clientConnectionSerializer.supportsOpMessage = reply.maxWireVersion.supportsOpMessage
            
            return
        }
    }
}

struct TransactionQueryOptions {
    let id: Int
    let startTransaction: Bool
    let autocommit: Bool
}

struct MongoDBCommandContext {
    var command: AnyMongoDBCommand
    var requestID: Int32
    var retry: Bool
    let session: ClientSession?
    let transaction: TransactionQueryOptions?
    var promise: EventLoopPromise<ServerReply>
}

final class ClientQueryContext {
    var queries = [MongoDBCommandContext]()
    var channelContext: ChannelHandlerContext?
    var isClosed = false
    
    func prepareForResend() {
        var i = queries.count
        
        while i > 0 {
            i = i &- 1
            var query = queries[i]
            if !query.retry {
                queries.remove(at: i)
                query.promise.fail(error: MongoKittenError(.protocolParsingError, reason: nil))
            } else {
                // TODO: This ensures only 1 retry, is that valid?
                query.retry = false
                queries[i] = query
            }
        }
    }
    
    func cancel(byId requestId: Int32) {
        if let index = self.queries.firstIndex(where: { $0.requestID == requestId }) {
            let query = self.queries[index]
            self.queries.remove(at: index)
            query.promise.fail(error: MongoKittenError(.commandFailure, reason: .commandCancelled))
        }
    }
    
    init() {}
    
    deinit {
        for query in queries {
            query.promise.fail(error: MongoKittenError(.unableToConnect, reason: nil))
        }
    }
}

final class ClientConnectionSerializer: MongoSerializer, MessageToByteEncoder {
    typealias OutboundIn = MongoDBCommandContext
    
    let context: ClientQueryContext
    
    init(context: ClientQueryContext) {
        self.context = context
        
        super.init()
    }
    
    func encode(ctx: ChannelHandlerContext, data: MongoDBCommandContext, out: inout ByteBuffer) throws {
        try encode(data: data, into: &out)
    }
}

final class ClientConnectionParser: MongoDeserializer, ByteToMessageDecoder {
    typealias InboundOut = ServerReply
    var cumulationBuffer: ByteBuffer?
    
    let context: ClientQueryContext
    
    init(context: ClientQueryContext) {
        self.context = context
    }
    
    func decode(ctx: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        let result = try parse(from: &buffer)
        
        if let reply = self.reply {
            if let index = self.context.queries.firstIndex(where: { $0.requestID == reply.responseTo }) {
                let query = self.context.queries[index]
                self.context.queries.remove(at: index)
                query.promise.succeed(result: reply)
            }
        }
        
        return result
    }
    
    // TODO: this does not belong here but on the next handler
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        self.context.prepareForResend()
        
        self.context.isClosed = true
        // TODO: Notify cluster to remove this connection
        // So that it can take the remaining queries and re-try them
        ctx.close(promise: nil)
    }
}

struct OpQueryFlags: OptionSet {
    let rawValue: UInt32
    
    /// Tailable cursors are not closed when the last data is received.
    static let tailableCursor = OpQueryFlags(rawValue: 1 << 1)
    
    /// This option allows querying a replica slave.
    static let slaveOk = OpQueryFlags(rawValue: 1 << 2)
    
    /// Only for internal replication use
    // static let oplogReplay = OpQueryFlags(rawValue: 1 << 3)
    
    /// Normally cursors get closed after 10 minutes of inactivity. This option prevents that
    static let noCursorTimeout = OpQueryFlags(rawValue: 1 << 4)
    
    /// To be used with TailableCursor. When at the end of the data, block for a while rather than returning no data.
    static let awaitData = OpQueryFlags(rawValue: 1 << 5)
    
    /// Stream the data down into a full blast of 'more' packages, MongoKitten will need to handle all data in one go.
//    static let exhaust = OpQueryFlags(rawValue: 1 << 6)
    
//    static let partial = OpQueryFlags(rawValue: 1 << 7)
}

struct OpMsgFlags: OptionSet {
    let rawValue: UInt32
    
    /// The message ends with 4 bytes containing a CRC-32C [1] checksum. See Checksum for details.
    static let checksumPresent = OpMsgFlags(rawValue: 1 << 0)
    
    /// Another message will follow this one without further action from the receiver. The receiver MUST NOT send another message until receiving one with moreToCome set to 0 as sends may block, causing deadlock. Requests with the moreToCome bit set will not receive a reply. Replies will only have this set in response to requests with the exhaustAllowed bit set.
    static let moreToCome = OpMsgFlags(rawValue: 1 << 1)
    
    /// The client is prepared for multiple replies to this request using the moreToCome bit. The server will never produce replies with the moreToCome bit set unless the request has this bit set.
    ///
    /// This ensures that multiple replies are only sent when the network layer of the requester is prepared for them. MongoDB 3.6 ignores this flag.
    static let exhaustAllowed = OpMsgFlags(rawValue: 1 << 16)
}
