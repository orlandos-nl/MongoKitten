import Foundation
import Bits

extension Message {
    struct Query: MessageType {
        /// The flags that are used by the Reply message
        struct Flags : OptionSet {
            /// The raw value in Int32
            let rawValue: Int32
            
            init(rawValue: Int32) { self.rawValue = rawValue }
            
            static let tailableCursor = InsertFlags(rawValue: 1 << 0)
            
            static let querySlaves = InsertFlags(rawValue: 1 << 1)
            
            static let noCursorTimeout = InsertFlags(rawValue: 1 << 3)
            
            static let awaitData = InsertFlags(rawValue: 1 << 4)
            
            static let exhaust = InsertFlags(rawValue: 1 << 5)
        }
        
        var storage: Buffer
        
        var flags: Flags {
            get {
                return Flags(rawValue: storage[Header.size])
            }
            set {
                storage[Header.size] = newValue.rawValue
            }
        }
        
        var fullCollectionName: String {
            // + Int32
            let offset = storage.buffer.baseAddress!.advanced(by: Header.size &+ 4)
            
            return String(cString: offset)
        }
        
        var fullCollectionNameSize: Int {
            // + Int32
            let offset = Header.size &+ 4
            var size = 0
            let buffer = storage.buffer
            
            while offset &+ size < buffer.count {
                size = size &+ 1
                
                if buffer.baseAddress![offset &+ size] == 0x00 {
                    // null terminator
                    return size &+ 1
                }
            }
            
            // null terminator
            return size &+ 1
        }
        
        var skip: Int32 {
            // + Int32 + cString
            get {
                return storage[Header.size &+ 4 &+ fullCollectionNameSize]
            }
            set {
                storage[Header.size &+ 4 &+ fullCollectionNameSize] = newValue
            }
        }
        
        var numberToReturn: Int32 {
            // + Int32 + cString + Int32
            get {
                return storage[Header.size &+ 4 &+ fullCollectionNameSize &+ 4]
            }
            set {
                storage[Header.size &+ 4 &+ fullCollectionNameSize &+ 4] = newValue
            }
        }
        
        var querySize: Int32 {
            // + Int32 + cString + Int32 + Int32
            return storage[Header.size &+ 4 &+ fullCollectionNameSize &+ 4 &+ 4]
        }
        
        var query: Document {
            // + Int32 + cString + Int32 + Int32
            let offset = storage.buffer.baseAddress!.advanced(by: Header.size &+ 4 &+ fullCollectionNameSize &+ 4 &+ 4)
            
            let buffer = ByteBuffer(start: offset, count: numericCast(self.querySize))
            return Document(data: Data(buffer: buffer))
        }
        
        var returnFieldsSize: Int? {
            // + Int32 + cString + Int32 + Int32 + Document
            let previousSize = Header.size &+ 4 &+ fullCollectionNameSize &+ 4 &+ 4 &+ numericCast(querySize)
            
            guard storage.buffer.count > previousSize &+ 4 else { return nil }
            
            let offset = storage.buffer.baseAddress!.advanced(by: previousSize)
            
            return offset.withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
                return numericCast(pointer.pointee)
            }
        }
        
        var returnFieldsSelector: Document? {
            guard let size = returnFieldsSize else { return nil }
            
            let offset = Header.size &+ 4 &+ fullCollectionNameSize &+ 4 &+ 4 &+ numericCast(querySize)
            
            guard storage.buffer.count >= offset &+ size else { return nil }
            
            let buffer = ByteBuffer(start: storage.buffer.baseAddress!.advanced(by: offset), count: size)
            return Document(data: Data(buffer: buffer))
        }
        
        var documents: [Document] {
            let offset = Header.size &+ 20
            let buffer = ByteBuffer(
                start: self.storage.buffer.baseAddress?.advanced(by: offset),
                count: self.storage.buffer.count &- offset
            )
            
            return [Document](bsonBytes: Data(buffer: buffer), validating: false)
        }
        
        init(
            requestId: Int32,
            flags: Flags = Flags(rawValue: 0),
            fullCollection: String,
            skip: Int32,
            return: Int32,
            query: Document
        ) {
            // length, header, flags, fullCollName, null, skip, limit, queryDoc
            let bufferSize = Int32(Message.Header.size &+ 4 &+ fullCollection.utf8.count &+ 9 &+ query.byteCount)
            
            self.storage = Buffer(size: numericCast(bufferSize))
            
            var header = Header(from: storage)
            header.requestId = requestId
            header.opCode = .query
            
            let writePointer = storage.mutableBuffer!.baseAddress!
            let stringSize = fullCollection.utf8.count
            
            fullCollection.withCString { pointer in
                writePointer.advanced(by: Message.Header.size &+ 4).assign(from: pointer, count: stringSize)
                
                // Explicitly add null terminator to override existing data
                writePointer[Message.Header.size &+ 4 &+ stringSize] = 0
            }
            
            self.flags = flags
            self.skip = skip
            self.numberToReturn = -1
            
            let data = query.makeBinary()
            
            data.withUnsafeBytes { (buffer: BytesPointer) in
                _ = memcpy(
                    writePointer.advanced(by: Message.Header.size &+ 4 &+ fullCollectionNameSize &+ 8),
                    buffer,
                    data.count
                )
            }
        }
    }
}
