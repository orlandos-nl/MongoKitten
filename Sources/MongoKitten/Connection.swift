import BSON
import NIO

// TODO: https://github.com/mongodb/specifications/blob/master/source/wireversion-featurelist.rst
// TODO: https://github.com/mongodb/specifications/tree/master/source/retryable-writes
// TODO: https://github.com/mongodb/specifications/blob/master/source/change-streams.rst

public final class MongoDBConnection {
    let parser = ClientConnectionParser()
    
    init(pipeline: ChannelPipeline) {
        pipeline.add(handler: parser)
    }
    
    init(_ uri: String) {
        // TODO: https://github.com/mongodb/specifications/tree/master/source/connection-string
        // TODO: https://github.com/mongodb/specifications/tree/master/source/initial-dns-seedlist-discovery
        // TODO: https://github.com/mongodb/specifications/tree/master/source/mongodb-handshake
        // TODO: https://github.com/mongodb/specifications/tree/master/source/max-staleness
        // TODO: https://github.com/mongodb/specifications/tree/master/source/server-selection
        // TODO: https://github.com/mongodb/specifications/tree/master/source/server-discovery-and-monitoring
        // TODO: https://github.com/mongodb/specifications/blob/master/source/driver-read-preferences.rst
    }
}

struct IncorrectServerReplyHeader: Error {}

final class ClientConnectionParser: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ServerReply
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        var buffer = self.unwrapInboundIn(data)
        
        do {
            let messageHeader = try buffer.parseMessageHeader()
            let reply: ServerReply
            
            switch messageHeader.opCode {
            case .reply:
                // <= Wire Version 5
                reply = try ServerReply.reply(fromBuffer: &buffer)
            case .message:
                reply = try ServerReply.message(fromBuffer: &buffer)
                // >= Wire Version 6
            default:
                throw IncorrectServerReplyHeader()
            }
            
            ctx.fireChannelRead(NIOAny(reply))
        } catch {
            ctx.fireErrorCaught(error)
        }
    }
    
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        // TODO: Fail all queries
        // TODO: Close connection
        // TODO: Reconnect? Trigger future/callback?
    }
}

struct ServerReply {
    var cursorId: Int64
    var documents: [Document]
    
    static func reply(fromBuffer buffer: inout ByteBuffer) throws -> ServerReply {
        // Skip responseFlags, they aren't interesting
        buffer.moveReaderIndex(forwardBy: 4)
        
        let cursorId = try buffer.assertLittleEndian() as Int64
        
        // Skip startingFrom, we don't expose this (yet)
        buffer.moveReaderIndex(forwardBy: 4)
        
        let numberReturned = try buffer.assertLittleEndian() as Int32
        
        let documents = try [Document](buffer: &buffer, count: numericCast(numberReturned))
        
        return ServerReply(cursorId: cursorId, documents: documents)
    }
    
    static func message(fromBuffer buffer: inout ByteBuffer) throws -> ServerReply {
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

extension ByteBuffer {
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
