import Async
import Bits
import Foundation

protocol MessageType {
    var header: Message.Header { get }
    var storage: Message.Buffer { get }
}

extension MessageType {
    var header: Message.Header {
        return .init(from: storage)
    }
}

enum Message {
    final class Buffer {
        enum Storage {
            case readable(ByteBuffer)
            case writable(MutableByteBuffer)
        }
        
        let storage: Storage
        
        var buffer: ByteBuffer {
            switch storage {
            case .readable(let buffer):
                return buffer
            case .writable(let buffer):
                return ByteBuffer(start: buffer.baseAddress, count: buffer.count)
            }
        }
        
        var mutableBuffer: MutableByteBuffer? {
            guard case .writable(let buffer) = storage else { return nil }
            return buffer
        }
        
        init(_ buffer: ByteBuffer) {
            self.storage = .readable(buffer)
        }
        
        init(_ buffer: MutableByteBuffer) {
            self.storage = .writable(buffer)
        }
        
        deinit {
            if case .writable(let buffer) = self.storage {
                buffer.baseAddress?.deallocate(capacity: buffer.count)
            }
        }
    }
    
    struct Header {
        static let size = 12 // 3x int32 (no length)
        
        private let storage: Buffer
        
        var requestId: Int32 {
            return storage.buffer.baseAddress!.withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
                return pointer.pointee
            }
            return storage.buffer.baseAddress!.withMemoryRebound(to: Int32.self)[1]
        }
        
        var responseTo: Int32 {
            return storage.buffer.baseAddress!.withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
                return pointer[1]
            }
            return storage.buffer.baseAddress!.withMemoryRebound(to: Int32.self)[2]
        }
        
        var opCode: Int32 {
            return storage.buffer.baseAddress!.withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
                return pointer[2]
            }
        }
        
        init(from buffer: Buffer) {
            self.storage = buffer
        }
    }
    
    struct Reply: MessageType {
        var storage: Buffer
        
        var flags: Int32 {
            let offset = storage.buffer.baseAddress!.advanced(by: Header.size)
                
            return offset.withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
                return pointer.pointee
            }
        }
        
        var cursorId: Int64 {
            // + Int32
            let offset = storage.buffer.baseAddress!.advanced(by: Header.size &+ 4)
                
            return offset.withMemoryRebound(to: Int64.self, capacity: 1) { pointer in
                return pointer.pointee
            }
        }
        
        var startingFrom: Int32 {
            // + Int32 + Int64
            let offset = storage.buffer.baseAddress!.advanced(by: Header.size &+ 12)
                
            return offset.withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
                return pointer.pointee
            }
        }
        
        var numberReturned: Int32 {
            // + Int32 + Int64 + Int32
            let offset = storage.buffer.baseAddress!.advanced(by: Header.size &+ 16)
            
            return offset.withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
                return pointer.pointee
            }
        }
        
        var documents: [Document] {
            let offset = Header.size &+ 20
            let buffer = ByteBuffer(
                start: self.storage.buffer.baseAddress?.advanced(by: offset),
                count: self.storage.buffer.count &- offset
            )
            
            return [Document](bsonBytes: Data(buffer: buffer), validating: false)
        }
    }
}

struct MessageParser: ByteParser {
    var state: ByteParserState<MessageParser>
    
    typealias Output = Message.Buffer
    
    enum ParsingState {
        case unknownLength([UInt8])
        case knownLength(buffer: Message.Buffer, accumulated: Int)
    }
    
    init() {
        self.state = .init()
    }
    
    func parseBytes(from buffer: ByteBuffer, partial: ParsingState?) throws -> Future<ByteParserResult<MessageParser>> {
        if let partial = partial {
            switch partial {
            case .unknownLength(var data):
                let missing = 4 &- data.count
                
                if buffer.count < missing {
                    return Future(.uncompleted(.unknownLength(data + Array(buffer))))
                }
                
                data.append(contentsOf: buffer[..<missing])
                let pointer = buffer.baseAddress!.advanced(by: missing)
                let size = buffer.count &- missing
                
                var _length: Int32 = 0
                memcpy(&_length, buffer.baseAddress!, 4)
                let length: Int = numericCast(_length)
                
                // length - Int32 length header
                if size < length &- 4 {
                    // Don't include length header
                    let messageSize = length &- 4
                    
                    let writePointer = MutableBytesPointer.allocate(capacity: messageSize)
                    memcpy(writePointer, pointer, size)
                    let mutableBuffer = Message.Buffer(MutableByteBuffer(start: writePointer, count: messageSize))
                    
                    return Future(.uncompleted(.knownLength(buffer: mutableBuffer, accumulated: size)))
                }
                
                let buffer = Message.Buffer(ByteBuffer(start: pointer, count: size))
                
                return Future(.completed(consuming: missing &+ size, result: buffer))
            case .knownLength(let message, let accumulated):
                let needed = message.buffer.count &- accumulated
                let copy = min(needed, buffer.count)
                memcpy(message.mutableBuffer!.baseAddress!.advanced(by: accumulated), buffer.baseAddress!, copy)
                
                if copy < needed {
                    return Future(.uncompleted(.knownLength(buffer: message, accumulated: accumulated &+ copy)))
                }
                
                return Future(.completed(consuming: copy, result: buffer))
            }
        } else {
            if buffer.count < 4 {
                return Future(.uncompleted(.unknownLength(Array(buffer))))
            }
            
            let length: Int = buffer.baseAddress!.withMemoryRebound(to: Int32.self, capacity: 1) { numericCast($0.pointee) }
            
            let messageStart = buffer.baseAddress!.advanced(by: 4)
            
            if buffer.count < length {
                // Don't include length header
                let messageSize = length &- 4
                
                let accumulating = buffer.count &- 4
                
                let writePointer = MutableBytesPointer.allocate(capacity: messageSize)
                memcpy(writePointer, messageStart, accumulating)
                let mutableBuffer = Message.Buffer(MutableByteBuffer(start: writePointer, count: messageSize))
                
                return Future(.uncompleted(.knownLength(buffer: mutableBuffer, accumulated: accumulating)))
            } else {
                let buffer = ByteBuffer(start: buffer.baseAddress!.advanced(by: 4), count: length &- 4)
                
                return Future(.completed(consuming: length, result: message.Buffer(buffer)))
            }
        }
    }
}
