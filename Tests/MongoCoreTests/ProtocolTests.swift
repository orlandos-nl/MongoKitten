import XCTest
import NIO
@testable import MongoCore

class ProtocolTests: XCTestCase {
    let allocator = ByteBufferAllocator()
    let sampleHeader: [UInt8] = [
        16 + 5, 0, 0, 0, // message length, header + body
        32, 0, 0, 0, // requestId
        0, 0, 0, 0, // responseId
        212, 7, 0, 0 // query OpCode
    ]
    
    func testHeaderEncoding() throws {
        var buffer = allocator.buffer(capacity: 0)
        let header = MongoMessageHeader(
            messageLength: 16 + 5,
            requestId: 32,
            responseTo: 0,
            opCode: .query
        )
        
        buffer.writeMongoHeader(header)
        let bytes = try buffer.bytes()
        
        XCTAssertEqual(Int32(bytes.count), MongoMessageHeader.byteSize)
        XCTAssertEqual(bytes, sampleHeader)
        
        let header2 = MongoMessageHeader(
            messageLength: 16 + 5,
            requestId: 32,
            responseTo: 0,
            opCode: .query
        )
        var buffer2 = allocator.buffer(capacity: 0)
        buffer2.writeMongoHeader(header2)
        
        XCTAssertEqual(bytes, try buffer2.bytes())
    }
    
    func testHeaderDecoding() throws {
        var buffer = allocator.buffer(capacity: sampleHeader.count)
        buffer.writeBytes(sampleHeader)
        
        let header = try buffer.assertReadMessageHeader()
        XCTAssertEqual(header.bodyLength, 5)
        XCTAssertEqual(header.requestId, 32)
        XCTAssertEqual(header.responseTo, 0)
        XCTAssertEqual(header.opCode, .query)
    }
    
    func testOpMessageEncoding() throws {
        let header = MongoMessageHeader(
            messageLength: 16 + 5,
            requestId: 32,
            responseTo: 0,
            opCode: .message
        )
        let document = Document()
        var buffer = allocator.buffer(capacity: 1_024)
        var documentBuffer = document.makeByteBuffer()
        
        buffer.writeInteger(0 as UInt32)
        buffer.writeInteger(0 as UInt8)
        buffer.writeBuffer(&documentBuffer)
        
        _ = try OpMessage(reading: &buffer, header: header)
    }
    
    func testOpMessageDeniesFirstUInt16Flags() throws {
        XCTAssertNoThrow(try OpMessage(reading: &buffer, header: header))
    }
}

extension ByteBuffer {
    func bytes() throws -> [UInt8] {
        guard let bytes = getBytes(at: 0, length: readableBytes) else {
            XCTFail()
            struct Failure: Error {}
            throw Failure()
        }
        
        return bytes
    }
}
