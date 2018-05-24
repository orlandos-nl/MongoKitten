import BSON
import NIO

// TODO: https://github.com/mongodb/specifications/blob/master/source/wireversion-featurelist.rst
// TODO: https://github.com/mongodb/specifications/tree/master/source/retryable-writes
// TODO: https://github.com/mongodb/specifications/blob/master/source/change-streams.rst

public final class MongoDBConnection {
    let context: ClientConnectionContext
    let eventloop: EventLoop
    
    public static func connect(on loop: EventLoop) throws -> EventLoopFuture<MongoDBConnection> {
        let context = ClientConnectionContext()
        
        let bootstrap = ClientBootstrap(group: loop)
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
        fatalError()
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
            ctx.fireChannelRead(wrapOutboundOut(command))
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
    
    init(context: ClientConnectionContext) {
        self.context = context
    }
    
    func encode(ctx: ChannelHandlerContext, data: MongoDBCommandContext, out: inout ByteBuffer) throws {
        var document = try BSONEncoder().encode(data.command)
        let headerIndex = out.writerIndex
        var flags: Int32 = 0
        
        out.moveWriterIndex(forwardBy: 24)
        
        if true {
            out.write(integer: flags)
            
            // cString
            out.write(string: data.command.collectionName)
            out.write(integer: 0 as UInt8)
            
            out.write(integer: 0 as Int32) // Number to skip, handled by query
            out.write(integer: 0 as Int32) // Number to return, handled by query
            
            let header = document.withUnsafeBufferPointer { buffer -> MessageHeader in
                out.write(bytes: buffer)
                
                return MessageHeader(
                    messageLength: numericCast(out.writerIndex &- headerIndex),
                    requestId: data.requestID,
                    responseTo: 0,
                    opCode: .query
                )
            }
            
            let endIndex = out.writerIndex
            out.write(header)
            
            out.moveWriterIndex(to: endIndex)
        } else {
            fatalError()
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
            let totalSize = (cumulationBuffer?.readableBytes ?? 0) + buffer.readableBytes
            
            if totalSize < 16 {
                return .needMoreData
            }
            
            header = try buffer.parseMessageHeader()
        }
        
        if numericCast(header.messageLength) &- 24 < buffer.readableBytes {
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
        write(integer: header.messageLength)
        write(integer: header.requestId)
        write(integer: header.responseTo)
        write(integer: header.opCode.rawValue)
    }
}

struct MessageHeader {
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
