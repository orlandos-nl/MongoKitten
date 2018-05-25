import BSON
import NIO
import Foundation


// TODO: https://github.com/mongodb/specifications/blob/master/source/wireversion-featurelist.rst
// TODO: https://github.com/mongodb/specifications/tree/master/source/retryable-writes
// TODO: https://github.com/mongodb/specifications/blob/master/source/change-streams.rst

/// A single MongoDB connection to a single MongoDB server.
/// `MongoDBConnection` handles the lowest level communication to a MongoDB instance.
public final class MongoDBConnection {
    let context: ClientConnectionContext
    let eventloop: EventLoop
    
    public static func connect(on group: EventLoopGroup) throws -> EventLoopFuture<MongoDBConnection> {
        let context = ClientConnectionContext()
        
        let bootstrap = ClientBootstrap(group: group)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return MongoDBConnection.initialize(pipeline: channel.pipeline, context: context)
            }
        
        return bootstrap.connect(host: "127.0.0.1", port: 27017).map { channel in
            return MongoDBConnection(channel: channel, context: context)
        }
    }
    
    init(channel: Channel, context: ClientConnectionContext) {
        self.eventloop = channel.eventLoop
        self.context = context
    }
    
    static func initialize(pipeline: ChannelPipeline, context: ClientConnectionContext) -> EventLoopFuture<Void> {
        return pipeline.add(handler: ClientConnectionParser(context: context)).then {
            pipeline.add(handler: ClientConnectionSerializer(context: context)).then {
                pipeline.add(handler: ClientConnectionHandler(context: context))
            }
        }
    }
    
    init(_ uri: String) {
        // TODO: https://github.com/mongodb/specifications/tree/master/source/connection-string
        // TODO: https://github.com/mongodb/specifications/tree/master/source/initial-dns-seedlist-discovery
        // TODO: https://github.com/mongodb/specifications/tree/master/source/mongodb-handshake
        // TODO: https://github.com/mongodb/specifications/tree/master/source/max-staleness
        // TODO: https://github.com/mongodb/specifications/tree/master/source/server-selection
        // TODO: https://github.com/mongodb/specifications/tree/master/source/server-discovery-and-monitoring
        // TODO: https://github.com/mongodb/specifications/blob/master/source/driver-read-preferences.rst
        unimplemented()
    }
    
    func _execute<C: AnyMongoDBCommand>(command: C) -> EventLoopFuture<ServerReply> {
        let promise: EventLoopPromise<ServerReply> = self.eventloop.newPromise()
        let command = MongoDBCommandContext(
            command: command,
            requestID: nextRequestId(),
            promise: promise
        )
        
        self.context.send(command)
        
        return promise.futureResult
    }
    
    func execute<C: MongoDBCommand>(command: C) -> EventLoopFuture<C.Result> {
        return _execute(command: command).thenThrowing(C.Result.init)
    }
    
    private func nextRequestId() -> Int32 {
        // TODO: Living cursors over time
        return 0
    }
}

struct IncorrectServerReplyHeader: Error {}

struct MongoDBCommandContext {
    var command: AnyMongoDBCommand
    var requestID: Int32
    var promise: EventLoopPromise<ServerReply>
}

final class ClientConnectionHandler: ChannelInboundHandler {
    typealias InboundIn = ServerReply
    typealias OutboundOut = MongoDBCommandContext
    
    let context: ClientConnectionContext
    
    init(context: ClientConnectionContext) {
        self.context = context
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let reply = unwrapInboundIn(data)
        let promise = context.queries[numericCast(reply.responseTo)]
        
        promise?.succeed(result: reply)
    }
    
    func channelActive(ctx: ChannelHandlerContext) {
        context.channelContext = ctx
        
        for command in context.unsentCommands {
//            ctx.write(wrapOutboundOut(command))
            _ = ctx.channel.writeAndFlush(command)
            context.queries[command.requestID] = command.promise
        }
        
        self.context.send = { command in
            ctx.fireChannelRead(self.wrapOutboundOut(command))
        }
        
        context.unsentCommands = []
    }
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
        document["$db"] = data.command.collectionReference.databaseName
        
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
        let namespace = data.command.collectionReference.databaseName + ".$cmd"
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
//        var document = try BSONEncoder().encode(data.command)
        
//        out.moveWriterIndex(forwardBy: 24)
//
//        if true {
//            out.write(integer: flags)
//
//            // cString
//            out.write(string: data.command.collectionName)
//            out.write(integer: 0 as UInt8)
//
//            out.write(integer: 0 as Int32) // Number to skip, handled by query
//            out.write(integer: 0 as Int32) // Number to return, handled by query
//
//            let header = document.withUnsafeBufferPointer { buffer -> MessageHeader in
//                out.write(bytes: buffer)
//
//                return MessageHeader(
//                    messageLength: numericCast(out.writerIndex &- headerIndex),
//                    requestId: data.requestID,
//                    responseTo: 0,
//                    opCode: .query
//                )
//            }
//
//            out.moveWriterIndex(to: 0)
//            let endIndex = out.writerIndex
//            out.write(header)
//
//            out.moveWriterIndex(to: endIndex)
//        } else {
//            fatalError()
//        }
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
            let totalSize = (cumulationBuffer?.readableBytes ?? 0) + buffer.readableBytes
            
            if totalSize < MessageHeader.byteSize {
                return .needMoreData
            }
            
            header = try buffer.parseMessageHeader()
        }
        
        if numericCast(header.messageLength) &- MessageHeader.byteSize < buffer.readableBytes {
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
        
        ctx.fireChannelRead(wrapInboundOut(reply))
        
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
        fatalError()
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
            
            _ = buffer.readWithUnsafeReadableBytes { buffer in
                let buffer = buffer.bindMemory(to: UInt8.self)
                
                let documentSize: Int = numericCast(documentSize)
                let documentBuffer = UnsafeBufferPointer(start: buffer.baseAddress, count: documentSize)
                let doc = Document(copying: documentBuffer, isArray: false)
                array.append(doc)
                
                return documentSize
            }
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
