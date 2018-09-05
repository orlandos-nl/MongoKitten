import BSON
import _MongoKittenCrypto
import NIO
import NIOOpenSSL
import Foundation

// TODO: https://github.com/mongodb/specifications/blob/master/source/wireversion-featurelist.rst
// TODO: https://github.com/mongodb/specifications/tree/master/source/retryable-writes
// TODO: https://github.com/mongodb/specifications/blob/master/source/change-streams.rst
// TODO: https://github.com/mongodb/specifications/tree/master/source/initial-dns-seedlist-discovery
// TODO: https://github.com/mongodb/specifications/tree/master/source/max-staleness
// TODO: https://github.com/mongodb/specifications/tree/master/source/server-selection
// TODO: https://github.com/mongodb/specifications/tree/master/source/server-discovery-and-monitoring
// TODO: https://github.com/mongodb/specifications/blob/master/source/driver-read-preferences.rst

/// A single MongoDB connection to a single MongoDB server.
/// `Connection` handles the lowest level communication to a MongoDB instance.
///
/// `Connection` is not threadsafe. It is bound to a single NIO EventLoop.
public final class Connection {
    
    deinit {
        _ = channel.close(mode: .all)
    }
    
    /// The NIO Client Connection Context
    let context: ClientConnectionContext
    
    /// The NIO channel
    let channel: Channel
    
    /// The connection settings for this connection
    let settings: ConnectionSettings
    
    /// The result of the `isMaster` handshake with the server
    public private(set) var handshakeResult: ConnectionHandshakeReply! = nil
    
    /// The current request ID, used to generate unique identifiers for MongoDB commands
    var currentRequestId: Int32 = 0
    
    /// The shared ObjectId generator for this connection
    internal let sharedGenerator = ObjectIdGenerator()
    
    private let clientConnectionSerializer: ClientConnectionSerializer
    
    /// The eventLoop this connection lives on
    public var eventLoop: EventLoop {
        return channel.eventLoop
    }
    
    /// Connects to the MongoDB server with the given `ConnectionSettings`
    ///
    /// - parameter group: The NIO EventLoopGroup or EventLoop to use for this connection
    /// - parameter settings: The connection settings to use
    /// - returns: A future that resolves with a connected connection if the connection was succesful, or with an error if the connection failed
    public static func connect(on group: EventLoopGroup, settings: ConnectionSettings) -> EventLoopFuture<Connection> {
        do {
            let context = ClientConnectionContext()
            let serializer = ClientConnectionSerializer(context: context)
            
            guard let host = settings.hosts.first else {
                throw MongoKittenError(.unableToConnect, reason: .noHostSpecified)
            }
            
            let bootstrap = ClientBootstrap(group: group)
                // Enable SO_REUSEADDR.
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .channelInitializer { channel in
                    return Connection.initialize(pipeline: channel.pipeline, hostname: host.hostname, context: context, settings: settings, serializer: serializer)
            }
            
            return bootstrap.connect(host: host.hostname, port: Int(host.port)).then { channel in
                let connection = Connection(channel: channel, context: context, settings: settings, serializer: serializer)
                
                return connection.executeHandshake()
                    .then { connection.authenticate() }
                    .map { connection }
            }
        } catch {
            return group.next().newFailedFuture(error: error)
        }
    }
    
    init(channel: Channel, context: ClientConnectionContext, settings: ConnectionSettings, serializer: ClientConnectionSerializer) {
        self.channel = channel
        self.context = context
        self.settings = settings
        self.clientConnectionSerializer = serializer
    }
    
    /// Returns the database named `database`, on this connection
    public subscript(database: String) -> Database {
        return Database(named: database, connection: self)
    }
    
    /// Returns the collection for the given namespace
    internal subscript(namespace: Namespace) -> Collection {
        return self[namespace.databaseName][namespace.collectionName]
    }
    
    static func initialize(pipeline: ChannelPipeline, hostname: String?, context: ClientConnectionContext, settings: ConnectionSettings, serializer: ClientConnectionSerializer) -> EventLoopFuture<Void> {
        let promise: EventLoopPromise<Void> = pipeline.eventLoop.newPromise()
        
        var handlers: [ChannelHandler] = [ClientConnectionParser(context: context), serializer]
        
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
    
    func _execute<C: AnyMongoDBCommand>(command: C) -> EventLoopFuture<ServerReply> {
        let promise: EventLoopPromise<ServerReply> = self.channel.eventLoop.newPromise()
        let command = MongoDBCommandContext(
            command: command,
            requestID: nextRequestId(),
            promise: promise
        )
        
        self.context.queries[command.requestID] = command.promise
        
        return self.channel.writeAndFlush(command).then { promise.futureResult }
    }
    
    /// Executes the given MongoDB command, returning the result
    ///
    /// - parameter command: The `MongoDBCommand` to execute
    /// - returns: The reply to the command
    func execute<C: MongoDBCommand>(command: C) -> EventLoopFuture<C.Reply> {
        return _execute(command: command).thenThrowing(C.Reply.init)
    }
    
    private func nextRequestId() -> Int32 {
        defer { currentRequestId = currentRequestId &+ 1}
        
        // TODO: Living cursors over time
        return currentRequestId
    }
    
    private func authenticate() -> EventLoopFuture<Void> {
        let source = settings.authenticationSource ?? "admin"
        let namespace = Namespace(to: "$cmd", inDatabase: source)
        
        switch settings.authentication {
        case .unauthenticated:
            return eventLoop.newSucceededFuture(result: ())
        case .scramSha1(let username, let password):
            return self.authenticateSASL(hasher: SHA1(), namespace: namespace, username: username, password: password)
        case .scramSha256(let username, let password):
            return self.authenticateSASL(hasher: SHA256(), namespace: namespace, username: username, password: password)
        default:
            unimplemented()
        }
    }
    
    private func executeHandshake() -> EventLoopFuture<Void> {
        // Construct app details
        let app: ConnectionHandshakeCommand.ClientDetails.ApplicationDetails?
        if let appName = settings.applicationName {
            app = .init(name: appName)
        } else {
            app = nil
        }
        
        let commandCollection = self["admin"]["$cmd"]
        
        return self.execute(command: ConnectionHandshakeCommand(application: app, collection: commandCollection)).map { reply in
            self.handshakeResult = reply
            
            self.clientConnectionSerializer.supportsOpMessage = reply.maxWireVersion >= 6
            
            return
        }
    }
}

struct MongoDBCommandContext {
    var command: AnyMongoDBCommand
    var requestID: Int32
    var promise: EventLoopPromise<ServerReply>
}

final class ClientConnectionContext {
    var queries = [Int32: EventLoopPromise<ServerReply>]()
    var channelContext: ChannelHandlerContext?
    var unsentCommands = [MongoDBCommandContext]()
    
    lazy var send: (MongoDBCommandContext) -> Void = { command in
        self.unsentCommands.append(command)
    }
    
    init() {}
}

final class ClientConnectionSerializer: MessageToByteEncoder {
    typealias OutboundIn = MongoDBCommandContext
    
    let context: ClientConnectionContext
    var supportsOpMessage = false
    let supportsQueryCommand = true
    
    init(context: ClientConnectionContext) {
        self.context = context
    }
    
    func encodeOpMessage(ctx: ChannelHandlerContext, data: MongoDBCommandContext, out: inout ByteBuffer) throws {
        let opCode = MessageHeader.OpCode.message
        
        let encoder = BSONEncoder()
        
        var document = try encoder.encode(data.command)
        document["$db"] = data.command.namespace.databaseName
        
        let flags: OpMsgFlags = []
        var buffer = document.makeByteBuffer()
        
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
        
        let document = try encoder.encode(data.command)
        
        let flags: UInt32 = 0
        var buffer = document.makeByteBuffer()
        let namespace = data.command.namespace.databaseName + ".$cmd"
        let namespaceSize = Int32(namespace.utf8.count) + 1
        
        let header = MessageHeader(
            messageLength: MessageHeader.byteSize + namespaceSize + 12 + Int32(buffer.readableBytes),
            requestId: data.requestID,
            responseTo: 0,
            opCode: opCode
        )
        
        out.write(header)
        out.write(integer: flags, endianness: .little)
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
            // TODO: Better error here
            throw MongoKittenError(.unsupportedProtocol, reason: nil)
        }
    }
}

final class ClientConnectionParser: ByteToMessageDecoder {
    typealias InboundOut = ServerReply
    var cumulationBuffer: ByteBuffer?
    var header: MessageHeader?
    
    let context: ClientConnectionContext
    
    init(context: ClientConnectionContext) {
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
        
        if let query = self.context.queries[reply.responseTo] {
            query.succeed(result: reply)
            self.context.queries[reply.responseTo] = nil
        }
        
        // TODO: Proper handling by passing the reply / error to the next handler
        
        self.header = nil
        return .continue
    }
    
    // TODO: this does not belong here but on the next handler
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        // TODO: Fail all queries
        // TODO: Close connection
        // TODO: Reconnect? Trigger future/callback?
        assertionFailure()
    }
}

struct OpMsgFlags: OptionSet {
    let rawValue: UInt32
    
    /// The message ends with 4 bytes containing a CRC-32C [1] checksum. See Checksum for details.
    static let checksumPresent = OpMsgFlags(rawValue: 1 << 0)
    
    /// Another message will follow this one without further action from the receiver. The receiver MUST NOT send another message until receiving one with moreToCome set to 0 as sends may block, causing deadlock. Requests with the moreToCome bit set will not receive a reply. Replies will only have this set in response to requests with the exhaustAllowed bit set.
    static let moreToCome = OpMsgFlags(rawValue: 1 << 1)
    
    /// The client is prepared for multiple replies to this request using the moreToCome bit. The server will never produce replies with the moreToCome bit set unless the request has this bit set.
    ///
    /// This ensures that multiple replies are only sent when the network layer of the requester is prepared for them.
    static let exhaustAllowed = OpMsgFlags(rawValue: 16 << 0)
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
