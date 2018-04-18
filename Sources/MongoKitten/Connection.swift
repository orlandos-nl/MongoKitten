import BSON
import NIO

// TODO: https://github.com/mongodb/specifications/blob/master/source/wireversion-featurelist.rst
// TODO: https://github.com/mongodb/specifications/tree/master/source/retryable-writes
// TODO: https://github.com/mongodb/specifications/blob/master/source/change-streams.rst

public final class MongoDBConnection {
    let reader = ClientConnectionParser()
    let writer = ClientConnectionSerializer()
    let cconnectionHandler = ClientConnectionHandler()
    let pipeline: ChannelPipeline
    
    init(pipeline: ChannelPipeline) {
        self.pipeline = pipeline
    }
    
    func doStuff() {
        self.cconnectionHandler
    }
    
    func initialize() -> EventLoopFuture<Void> {
        return pipeline.add(handler: self.reader).then {
            self.pipeline.add(handler: self.writer).then {
                self.pipeline.add(handler: self.cconnectionHandler)
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
}

struct IncorrectServerReplyHeader: Error {}

final class ClientConnectionHandler: ChannelInboundHandler {
    typealias InboundIn = ServerReply
    typealias OutboundOut = ByteBuffer
    
    var queries = [Int: EventLoopPromise<ServerReply>]()
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let reply = unwrapInboundIn(data)
        let promise = queries[numericCast(reply.responseTo)]
        
        promise?.succeed(result: reply)
    }
    
    func channelActive(ctx: ChannelHandlerContext) {
        
    }
}

protocol Command: Codable {
    var collectionName: String { get }
}

final class ClientConnectionSerializer: MessageToByteEncoder {
    typealias OutboundIn = Command
    var opQuery = true
    
    func encode(ctx: ChannelHandlerContext, data: Command, out: inout ByteBuffer) throws {
        var document = try BSONEncoder().encode(data)
        let headerIndex = out.writerIndex
        var flags: Int32 = 0
        
        out.moveWriterIndex(forwardBy: 24)
        
        if opQuery {
            out.write(integer: flags)
            
            // cString
            out.write(string: data.collectionName)
            out.write(integer: 0 as UInt8)
            
            out.write(integer: 0 as Int32) // Number to skip, handled by query
            out.write(integer: 0 as Int32) // Number to return, handled by query
            
            let header = document.withUnsafeBufferPointer { buffer -> MessageHeader in
                out.write(bytes: buffer)
                
                return MessageHeader(
                    messageLength: numericCast(out.writerIndex &- headerIndex),
                    requestId: nextRequestId(),
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
    
    func nextRequestId() -> Int32 {
        // TODO: Living cursors over time
        return 0
    }
}

final class ClientConnectionParser: ByteToMessageDecoder {
    typealias InboundOut = ServerReply
    
    var cumulationBuffer: ByteBuffer?
    var header: MessageHeader?
    
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
