import Foundation
import BSON
import NIO

/// A type capable of deserializing messages from MongoDB
struct MongoDeserializer {
    private var header: MessageHeader?
    private(set) var reply: ServerReply?
    
    /// Parses a buffer into a server reply
    ///
    /// Returns `.continue` if enough data was read for a single reply
    ///
    /// Sets `reply` to a the found ServerReply when done parsing it.
    /// It's replaced with a new reply the next successful iteration of the parser so needs to be extracted after each `parse` attempt
    ///
    /// Any remaining data left in the `buffer` needs to be left until the next interation, which NIO does by default
    mutating func parse(from buffer: inout ByteBuffer) throws -> DecodingState {
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
        
        switch header.opCode {
        case .reply:
            // <= Wire Version 5
            self.reply = try ServerReply.reply(fromBuffer: &buffer, responseTo: header.responseTo)
        case .message:
            // >= Wire Version 6
            self.reply = try ServerReply.message(fromBuffer: &buffer, responseTo: header.responseTo, header: header)
        default:
            throw MongoKittenError(.protocolParsingError, reason: .unsupportedOpCode)
        }
        
        // TODO: Proper handling by passing the reply / error to the next handler
        
        self.header = nil
        return .continue
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
    
    mutating func readCString() throws -> String {
        var bytes = Data()
        while let byte = self.readInteger(endianness: .little, as: UInt8.self), byte != 0 {
            bytes.append(byte)
        }
        
        return try String(data: bytes, encoding: .utf8).assert()
    }
}
