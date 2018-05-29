import BSON
import NIO
import Foundation

// TODO: https://github.com/mongodb/specifications/blob/master/source/wireversion-featurelist.rst
// TODO: https://github.com/mongodb/specifications/tree/master/source/retryable-writes
// TODO: https://github.com/mongodb/specifications/blob/master/source/change-streams.rst
// TODO: https://github.com/mongodb/specifications/tree/master/source/initial-dns-seedlist-discovery
// TODO: https://github.com/mongodb/specifications/tree/master/source/mongodb-handshake
// TODO: https://github.com/mongodb/specifications/tree/master/source/max-staleness
// TODO: https://github.com/mongodb/specifications/tree/master/source/server-selection
// TODO: https://github.com/mongodb/specifications/tree/master/source/server-discovery-and-monitoring
// TODO: https://github.com/mongodb/specifications/blob/master/source/driver-read-preferences.rst

/// A single MongoDB connection to a single MongoDB server.
/// `MongoDBConnection` handles the lowest level communication to a MongoDB instance.
public final class MongoDBConnection {
    let context: ClientConnectionContext
    let channel: Channel
    var currentRequestId: Int32 = 0
    internal let sharedGenerator = ObjectIdGenerator()
    
    public var eventLoop: EventLoop {
        return channel.eventLoop
    }
    
    public static func connect(on group: EventLoopGroup, settings: ConnectionSettings) -> EventLoopFuture<MongoDBConnection> {
        do {
            let context = ClientConnectionContext()
            
            let bootstrap = ClientBootstrap(group: group)
                // Enable SO_REUSEADDR.
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .channelInitializer { channel in
                    return MongoDBConnection.initialize(pipeline: channel.pipeline, context: context)
            }
            
            guard let host = settings.hosts.first else {
                throw MongoKittenError(.unableToConnect, reason: .noHostSpecified)
            }
            
            return bootstrap.connect(host: host.hostname, port: Int(host.port)).map { channel in
                return MongoDBConnection(channel: channel, context: context)
            }
        } catch {
            return group.next().newFailedFuture(error: error)
        }
    }
    
    init(channel: Channel, context: ClientConnectionContext) {
        self.channel = channel
        self.context = context
    }
    
    public subscript(database: String) -> Database {
        return Database(named: database, connection: self)
    }
    
    internal subscript(namespace: Namespace) -> Collection {
        return self[namespace.databaseName][namespace.collectionName]
    }
    
    static func initialize(pipeline: ChannelPipeline, context: ClientConnectionContext) -> EventLoopFuture<Void> {
        return pipeline.add(handler: ClientConnectionParser(context: context)).then {
            pipeline.add(handler: ClientConnectionSerializer(context: context))
        }
    }
    
    func _execute<C: AnyMongoDBCommand>(command: C) -> EventLoopFuture<ServerReply> {
        let promise: EventLoopPromise<ServerReply> = self.channel.eventLoop.newPromise()
        let command = MongoDBCommandContext(
            command: command,
            requestID: nextRequestId(),
            promise: promise
        )
        
        self.context.queries[command.requestID] = command.promise
        
        _ = self.channel.writeAndFlush(command)
        
        return promise.futureResult
    }
    
    func execute<C: MongoDBCommand>(command: C) -> EventLoopFuture<C.Reply> {
        return _execute(command: command).thenThrowing(C.Reply.init)
    }
    
    private func nextRequestId() -> Int32 {
        defer { currentRequestId = currentRequestId &+ 1}
        
        // TODO: Living cursors over time
        return currentRequestId
    }
}

struct IncorrectServerReplyHeader: Error {}

struct MongoDBCommandContext {
    var command: AnyMongoDBCommand
    var requestID: Int32
    var promise: EventLoopPromise<ServerReply>
}

final class ClientConnectionContext {
    var queries = [Int32: EventLoopPromise<ServerReply>]()
    var channelContext: ChannelHandlerContext?
    var unsentCommands = [MongoDBCommandContext]()
    
    lazy var send: (MongoDBCommandContext) -> () = { command in
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
        
        let flags: UInt32 = 0
        let docData = document.makeData()
        
        let header = MessageHeader(
            messageLength: MessageHeader.byteSize + 4 + 1 + Int32(docData.count),
            requestId: data.requestID,
            responseTo: 0,
            opCode: opCode
        )
        
        out.write(header)
        out.write(integer: flags, endianness: .little)
        out.write(integer: 0 as UInt8, endianness: .little) // section kind 0
        
        // TODO: Use ByteBuffer in BSON
        out.write(bytes: docData)
    }
    
    func encodeQueryCommand(ctx: ChannelHandlerContext, data: MongoDBCommandContext, out: inout ByteBuffer) throws {
        let opCode = MessageHeader.OpCode.query
        
        let encoder = BSONEncoder()
        
        var document = try encoder.encode(data.command)
        
        let flags: UInt32 = 0
        let docData = document.makeData()
        let namespace = data.command.namespace.databaseName + ".$cmd"
        let namespaceSize = Int32(namespace.utf8.count) + 1
        
        let header = MessageHeader(
            messageLength: MessageHeader.byteSize + namespaceSize + 12 + Int32(docData.count),
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
        
        // TODO: Use ByteBuffer in BSON
        out.write(bytes: docData)
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
            reply = try ServerReply.message(fromBuffer: &buffer, responseTo: header.responseTo)
        // >= Wire Version 6
        default:
            throw IncorrectServerReplyHeader()
        }
        
        self.context.queries[reply.responseTo]?.succeed(result: reply)
        
        self.header = nil
        return .continue
    }
    
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        // TODO: Fail all queries
        // TODO: Close connection
        // TODO: Reconnect? Trigger future/callback?
    }
}

struct ServerReply {
    var responseTo: Int32
    var cursorId: Int64
    var documents: [Document]
    
    static func reply(fromBuffer buffer: inout ByteBuffer, responseTo: Int32) throws -> ServerReply {
        // Skip responseFlags, they aren't interesting
        buffer.moveReaderIndex(forwardBy: 4)
        
        let cursorId = try buffer.assertLittleEndian() as Int64
        
        // Skip startingFrom, we don't expose this (yet)
        buffer.moveReaderIndex(forwardBy: 4)
        
        let numberReturned = try buffer.assertLittleEndian() as Int32
        
        let documents = try [Document](buffer: &buffer, count: numericCast(numberReturned))
        
        return ServerReply(responseTo: responseTo, cursorId: cursorId, documents: documents)
    }
    
    static func message(fromBuffer buffer: inout ByteBuffer, responseTo: Int32) throws -> ServerReply {
        unimplemented()
    }
}

extension Array where Element == Document {
    init(buffer: inout ByteBuffer, count: Int) throws {
        var array = [Document]()
        array.reserveCapacity(count)
        
        for _ in 0..<count {
            let documentSize = try buffer.getInteger(
                at: buffer.readerIndex,
                endianness: .little,
                as: Int32.self
            ).assert()
            
            guard let bytes = buffer.readBytes(length: numericCast(documentSize)) else {
                throw MongoKittenError(.protocolParsingError, reason: nil)
            }
            
            array.append(Document(bytes: bytes))
        }
        
        self = array
    }
}

fileprivate extension Optional {
    func assert() throws -> Wrapped {
        guard let me = self else {
            throw IncorrectServerReplyHeader()
        }
        
        return me
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
