import BSON
import _MongoKittenCrypto
import NIO

#if canImport(NIOTransportServices)
import NIOTransportServices
import Network
public typealias _MKNIOEventLoopRequirement = NIOTSEventLoopGroup
#else
import NIOOpenSSL
public typealias _MKNIOEventLoopRequirement = EventLoopGroup
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
    var implicitSession: ClientSession!
    
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
    var currentRequestId: Int32 = 0
    
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
        
        let bootstrap = ClientBootstrap(group: cluster.eventLoop)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return Connection.initialize(
                    pipeline: channel.pipeline,
                    hostname: host.hostname,
                    context: context,
                    settings: cluster.settings,
                    serializer: serializer
                )
        }
        
        return bootstrap.connect(host: host.hostname, port: Int(host.port)).then { channel in
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
    
    static func initialize(pipeline: ChannelPipeline, hostname: String?, context: ClientQueryContext, settings: ConnectionSettings, serializer: ClientConnectionSerializer) -> EventLoopFuture<Void> {
        let promise: EventLoopPromise<Void> = pipeline.eventLoop.newPromise()
        
        var handlers: [ChannelHandler] = [ClientConnectionParser(context: context), serializer]
        
        #if canImport(NIOTransportServices)
        var bootstrap = NIOTSConnectionBootstrap(group: group)
        
        if settings.useSSL {
            bootstrap = bootstrap.tlsOptions(NWProtocolTLS.Options())
        }
        #else
        if settings.useSSL {
            do {
                let sslConfiguration = TLSConfiguration.forClient(
                    certificateVerification: settings.verifySSLCertificates ? .fullVerification : .none
                )
                
                let sslContext = try SSLContext(configuration: sslConfiguration)
                let sslHandler = try OpenSSLClientHandler(context: sslContext, serverHostname: hostname)
                
                handlers.insert(sslHandler, at: 0)
            } catch {
                promise.fail(error: error)
                return promise.futureResult
            }
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
    
    private func nextRequestId() -> Int32 {
        defer { currentRequestId = currentRequestId &+ 1}
        
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
        
        let commandCollection = self.implicitSession.cluster["admin"]["$cmd"]
        
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
    
    init() {}
    
    deinit {
        for query in queries {
            query.promise.fail(error: MongoKittenError(.unableToConnect, reason: nil))
        }
    }
}

final class ClientConnectionSerializer: MessageToByteEncoder {
    typealias OutboundIn = MongoDBCommandContext
    
    let context: ClientQueryContext
    var supportsOpMessage = false
    var slaveOk = false
    var includeSession = false
    let supportsQueryCommand = true
    
    init(context: ClientQueryContext) {
        self.context = context
    }
    
    func encodeOpMessage(ctx: ChannelHandlerContext, data: MongoDBCommandContext, out: inout ByteBuffer) throws {
        let opCode = MessageHeader.OpCode.message
        
        let encoder = BSONEncoder()
        
        var document = try encoder.encode(data.command)
        document["$db"] = data.command.namespace.databaseName
        
        if includeSession, let session = data.session {
            document["lsid"]["id"] = session.sessionId.id
        }
        
        if let transaction = data.transaction {
            document["txnNumber"] = transaction.id
            document["autocommit"] = transaction.autocommit
            
            if transaction.startTransaction {
                document["startTransaction"] = true
            }
        }
        
        let flags: OpMsgFlags = []
        
        var buffer = document.makeByteBuffer()
        
        // MongoDB supports messages up to 16MB
        if buffer.writerIndex > 16_000_000 {
            data.promise.fail(error: MongoKittenError(.commandFailure, reason: MongoKittenError.Reason.commandSizeTooLarge))
            return
        }
        
        let header = MessageHeader(
            messageLength: MessageHeader.byteSize + 4 + 1 + Int32(buffer.readableBytes),
            requestId: data.requestID,
            responseTo: 0,
            opCode: opCode
        )
        
        out.write(header)
        out.write(integer: flags.rawValue, endianness: .little)
        out.write(integer: 0 as UInt8, endianness: .little) // section kind 0
        
        out.write(buffer: &buffer)
    }
    
    func encodeQueryCommand(ctx: ChannelHandlerContext, data: MongoDBCommandContext, out: inout ByteBuffer) throws {
        let opCode = MessageHeader.OpCode.query
        
        let encoder = BSONEncoder()
        
        var document = try encoder.encode(data.command)
        
        if includeSession, let session = data.session {
            document["lsid"]["id"] = session.sessionId.id
        }
        
        var flags: OpQueryFlags = []
        
        if slaveOk {
            flags.insert(.slaveOk)
        }
        
        var buffer = document.makeByteBuffer()
        
        // MongoDB supports messages up to 16MB
        if buffer.writerIndex > 16_000_000 {
            data.promise.fail(error: MongoKittenError(.commandFailure, reason: MongoKittenError.Reason.commandSizeTooLarge))
            return
        }
        
        let namespace = data.command.namespace.databaseName + ".$cmd"
        let namespaceSize = Int32(namespace.utf8.count) + 1
        
        let header = MessageHeader(
            messageLength: MessageHeader.byteSize + namespaceSize + 12 + Int32(buffer.readableBytes),
            requestId: data.requestID,
            responseTo: 0,
            opCode: opCode
        )
        
        out.write(header)
        out.write(integer: flags.rawValue, endianness: .little)
        out.write(string: namespace)
        out.write(integer: 0 as UInt8) // null terminator for String
        out.write(integer: 0 as Int32, endianness: .little) // Skip handled by query
        out.write(integer: 1 as Int32, endianness: .little) // Number to return
        
        out.write(buffer: &buffer)
    }
    
    func encode(ctx: ChannelHandlerContext, data: MongoDBCommandContext, out: inout ByteBuffer) throws {
        if supportsOpMessage {
            try encodeOpMessage(ctx: ctx, data: data, out: &out)
        } else if supportsQueryCommand {
            try encodeQueryCommand(ctx: ctx, data: data, out: &out)
        } else {
            throw MongoKittenError(.unsupportedProtocol, reason: nil)
        }
    }
}

final class ClientConnectionParser: ByteToMessageDecoder {
    typealias InboundOut = ServerReply
    var cumulationBuffer: ByteBuffer?
    var header: MessageHeader?
    
    let context: ClientQueryContext
    
    init(context: ClientQueryContext) {
        self.context = context
    }
    
    func decode(ctx: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        let header: MessageHeader
        
        if let _header = self.header {
            header = _header
        } else {
            if buffer.readableBytes < MessageHeader.byteSize {
                return .needMoreData
            }
            
            header = try buffer.parseMessageHeader()
        }
        
        guard numericCast(header.messageLength) &- MessageHeader.byteSize <= buffer.readableBytes else {
            self.header = header
            return .needMoreData
        }
        
        self.header = nil
        let reply: ServerReply
        
        switch header.opCode {
        case .reply:
            // <= Wire Version 5
            reply = try ServerReply.reply(fromBuffer: &buffer, responseTo: header.responseTo)
        case .message:
            // >= Wire Version 6
            reply = try ServerReply.message(fromBuffer: &buffer, responseTo: header.responseTo, header: header)
        default:
            throw MongoKittenError(.protocolParsingError, reason: .unsupportedOpCode)
        }
        
        if let index = self.context.queries.firstIndex(where: { $0.requestID == reply.responseTo }) {
            self.context.queries[index].promise.succeed(result: reply)
            self.context.queries.remove(at: index)
        }
        
        // TODO: Proper handling by passing the reply / error to the next handler
        
        self.header = nil
        return .continue
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

struct ServerReply {
    var responseTo: Int32
    var cursorId: Int64 // 0 for OP_MSG
    var documents: [Document]
    
    static func reply(fromBuffer buffer: inout ByteBuffer, responseTo: Int32) throws -> ServerReply {
        // Skip responseFlags for now
        buffer.moveReaderIndex(forwardBy: 4)
        
        let cursorId = try buffer.assertLittleEndian() as Int64
        
        // Skip startingFrom, we don't expose this (yet)
        buffer.moveReaderIndex(forwardBy: 4)
        
        let numberReturned = try buffer.assertLittleEndian() as Int32
        
        let documents = try [Document](buffer: &buffer, count: numericCast(numberReturned))
        
        return ServerReply(responseTo: responseTo, cursorId: cursorId, documents: documents)
    }
    
    static func message(fromBuffer buffer: inout ByteBuffer, responseTo: Int32, header: MessageHeader) throws -> ServerReply {
        // Read flags
        // TODO: The first 16 bits (0-15) are required and parsers MUST error if an unknown bit is set.
        let rawFlags = try buffer.assertLittleEndian() as UInt32
        let flags = OpMsgFlags(rawValue: rawFlags) // TODO: Handle flags, like checksum
        
        var documents: [Document] = []
        
        var sectionsSize = Int(header.messageLength - MessageHeader.byteSize - 4)
        if flags.contains(.checksumPresent) {
            sectionsSize -= 4
        }
        
        let readerIndexAfterSectionParsing = buffer.readerIndex + sectionsSize
        
        // minimum BSON size is 5, checksum is 4 bytes, so this works
        while buffer.readerIndex < readerIndexAfterSectionParsing {
            let kind = try buffer.assertLittleEndian() as UInt8
            switch kind {
            case 0: // body
                documents += try [Document](buffer: &buffer, count: 1)
            case 1: // document sequence
                let size = try buffer.assertLittleEndian() as Int32
                let documentSequenceIdentifier = try buffer.readCString() // Document sequence identifier
                // TODO: Handle document sequence identifier correctly
                
                let bsonObjectsSectionSize = Int(size) - 4 - documentSequenceIdentifier.utf8.count - 1
                guard bsonObjectsSectionSize > 0 else {
                    // TODO: Investigate why this error gets silienced
                    throw MongoKittenError(.protocolParsingError, reason: .unexpectedValue)
                }
                
                documents += try [Document](buffer: &buffer, consumeBytes: bsonObjectsSectionSize)
            default:
                // TODO: Investigate why this error gets silienced
                throw MongoKittenError(.protocolParsingError, reason: .unexpectedValue)
            }
        }
        
        if flags.contains(.checksumPresent) {
            // Checksum validation is unimplemented
            // MongoDB 3.6 does not support validating the message checksum, but will correctly skip it if present.
            buffer.moveReaderIndex(forwardBy: 4)
        }
        
        return ServerReply(responseTo: responseTo, cursorId: 0, documents: documents)
    }
}

extension Array where Element == Document {
    init(buffer: inout ByteBuffer, count: Int) throws {
        self = []
        reserveCapacity(count)
        
        for _ in 0..<count {
            let documentSize = try buffer.getInteger(
                at: buffer.readerIndex,
                endianness: .little,
                as: Int32.self
            ).assert()
            
            guard let bytes = buffer.readBytes(length: numericCast(documentSize)) else {
                throw MongoKittenError(.protocolParsingError, reason: nil)
            }
            
            append(Document(bytes: bytes))
        }
    }
    
    init(buffer: inout ByteBuffer, consumeBytes: Int) throws {
        self = []
        
        var consumedBytes = 0
        while consumedBytes < consumeBytes {
            let documentSize = try buffer.getInteger(
                at: buffer.readerIndex,
                endianness: .little,
                as: Int32.self
                ).assert()
            
            consumedBytes += Int(documentSize)
            
            guard let bytes = buffer.readBytes(length: numericCast(documentSize)) else {
                throw MongoKittenError(.protocolParsingError, reason: nil)
            }
            
            append(Document(bytes: bytes))
        }
    }
}

fileprivate extension Optional {
    func assert() throws -> Wrapped {
        guard let `self` = self else {
            throw MongoKittenError(.unexpectedNil, reason: nil)
        }
        
        return self
    }
}

fileprivate extension ByteBuffer {
    mutating func assertLittleEndian<FWI: FixedWidthInteger>() throws -> FWI {
        return try self.readInteger(endianness: .little, as: FWI.self).assert()
    }
    
    mutating func assertOpCode() throws -> MessageHeader.OpCode {
        return try MessageHeader.OpCode(rawValue: try assertLittleEndian()) .assert()
    }
    
    mutating func parseMessageHeader() throws -> MessageHeader {
        return try MessageHeader(
            messageLength: assertLittleEndian(),
            requestId: assertLittleEndian(),
            responseTo: assertLittleEndian(),
            opCode: assertOpCode()
        )
    }
    
    mutating func write(_ header: MessageHeader) {
        write(integer: header.messageLength, endianness: .little)
        write(integer: header.requestId, endianness: .little)
        write(integer: header.responseTo, endianness: .little)
        write(integer: header.opCode.rawValue, endianness: .little)
    }
    
    mutating func readCString() throws -> String {
        var bytes = Data()
        while let byte = self.readInteger(endianness: .little, as: UInt8.self), byte != 0 {
            bytes.append(byte)
        }
        
        return try String(data: bytes, encoding: .utf8).assert()
    }
}

struct MessageHeader {
    static let byteSize: Int32 = 16
    
    enum OpCode: Int32 {
        case reply = 1
        case update = 2001
        case insert = 2002
        // Reserved = 2003
        case query = 2004
        case getMore = 2005
        case delete = 2006
        case killCursors = 2007
        case message = 2013
    }
    
    var messageLength: Int32
    var requestId: Int32
    var responseTo: Int32
    var opCode: OpCode
}
