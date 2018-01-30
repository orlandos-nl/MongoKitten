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
        
        init(size: Int) {
            let pointer = MutableBytesPointer.allocate(capacity: size)
            let buffer = MutableByteBuffer(start: pointer, count: size)
            self.storage = .writable(buffer)
        }
        
        deinit {
            if case .writable(let buffer) = self.storage {
                buffer.baseAddress?.deallocate(capacity: buffer.count)
            }
        }
    }
    
    enum OpCode: Int32 {
        case reply = 1
        case update = 2001
        case insert = 2002
        case query = 2004
        case getMore = 2005
        case delete = 2006
        case killCursors = 2007
        case msg = 2013
    }
    
    struct Header {
        static let size = 16 // 3x int32 (no length)
        
        private let storage: Buffer
        
        var length: Int32 {
            get {
                return storage[0]
            }
            set {
                storage[0] = newValue
            }
        }
        
        var requestId: Int32 {
            get {
                return storage[4]
            }
            set {
                storage[4] = newValue
            }
        }
        
        var responseTo: Int32 {
            get {
                return storage[8]
            }
            set {
                storage[8] = newValue
            }
        }
        
        var opCode: OpCode? {
            get {
                return OpCode(rawValue: storage[12])
            }
            set {
                storage[12] = newValue?.rawValue ?? 0
            }
        }
        
        init(from buffer: Buffer) {
            self.storage = buffer
            
            if case .writable(_) = buffer.storage {
                self.length = numericCast(storage.buffer.count)
            }
        }
    }
}

extension Message.Buffer {
    subscript(pos: Int) -> Int32 {
        get {
            return buffer.baseAddress!.advanced(by: pos).withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
                return pointer.pointee
            }
        }
        set {
            mutableBuffer!.baseAddress!.advanced(by: pos).withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
                pointer.pointee = newValue
            }
        }
    }
    
    subscript(pos: Int) -> Int64 {
        get {
            return buffer.baseAddress!.advanced(by: pos).withMemoryRebound(to: Int64.self, capacity: 1) { pointer in
                return pointer.pointee
            }
        }
        set {
            mutableBuffer!.baseAddress!.advanced(by: pos).withMemoryRebound(to: Int64.self, capacity: 1) { pointer in
                pointer.pointee = newValue
            }
        }
    }
}
