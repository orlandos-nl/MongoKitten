import Foundation
import NIO
import BSON

extension Array where Element == Document {
    init(buffer: inout ByteBuffer, count: Int) throws {
        self.init()
        reserveCapacity(count)
        
        for _ in 0..<count {
            try append(buffer.assertReadDocument())
        }
    }
    
    init(buffer: inout ByteBuffer, consumeBytes: Int) throws {
        self.init()
        
        let finalConsumedBytes = buffer.readerIndex + consumeBytes
        while buffer.readerIndex < finalConsumedBytes {
            try append(buffer.assertReadDocument())
        }
    }
}

fileprivate extension Optional {
    func assert() throws -> Wrapped {
        guard let `self` = self else {
            throw MongoOptionalUnwrapFailure()
        }
        
        return self
    }
}

extension ByteBuffer {
    mutating func assertReadDocument() throws -> Document {
        let documentSize = try getInteger(
            at: readerIndex,
            endianness: .little,
            as: Int32.self
        ).assert()
        
        guard let slice = readSlice(length: numericCast(documentSize)) else {
            throw MongoProtocolParsingError(reason: .missingDocumentBody)
        }
        
        return Document(buffer: slice)
    }
    
    mutating func assertLittleEndian<FWI: FixedWidthInteger>() throws -> FWI {
        return try self.readInteger(endianness: .little, as: FWI.self).assert()
    }
    
    mutating func readCString() throws -> String {
        return try self.readWithUnsafeReadableBytes { buffer -> (Int, String?) in
            var i = 0
            for byte in buffer {
                i += 1
                if byte == 0x00 {
                    let string = String(cString: buffer.baseAddress!.assumingMemoryBound(to: UInt8.self))
                    return (i, string)
                }
            }
            
            return (0, nil)
        }.assert()
    }
}

extension ByteBuffer {
    public mutating func writeMongoHeader(_ header: MongoMessageHeader) {
        writeInteger(header.messageLength, endianness: .little)
        writeInteger(header.requestId, endianness: .little)
        writeInteger(header.responseTo, endianness: .little)
        writeInteger(header.opCode.rawValue, endianness: .little)
    }
    
    mutating func assertOpCode() throws -> MongoMessageHeader.OpCode {
        return try MongoMessageHeader.OpCode(rawValue: try assertLittleEndian()) .assert()
    }
    
    public mutating func assertReadMessageHeader() throws -> MongoMessageHeader {
        return try MongoMessageHeader(
            messageLength: assertLittleEndian(),
            requestId: assertLittleEndian(),
            responseTo: assertLittleEndian(),
            opCode: assertOpCode()
        )
    }
}
