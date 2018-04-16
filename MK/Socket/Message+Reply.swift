import Foundation
import Bits

extension Message {
    struct Reply: MessageType {
        /// The flags that are used by the Reply message
        struct Flags : OptionSet {
            /// The raw value in Int32
            let rawValue: Int32
            
            /// You can initialize this with an Int32 and compare the number with an array of ReplyFlags
            init(rawValue: Int32) { self.rawValue = rawValue }
            
            /// The server could not find the cursor we tried to use
            static let cursorNotFound = Flags(rawValue: 1 << 0)
            
            /// The query we entered failed
            static let queryFailure = Flags(rawValue: 1 << 1)
            
            /// The server is await-capable and thus supports the QueryFlag's AwaitData flag
            static let awaitCapable = Flags(rawValue: 1 << 3)
        }
        
        var storage: Buffer
        
        init(_ storage: Buffer) throws {
            guard storage.buffer.count == Header(from: storage).length else {
                throw MongoParserError.invalidReply
            }
            
            self.storage = storage
        }
        
        var flags: Flags {
            get {
                return Flags(rawValue: storage[Header.size])
            }
            set {
                storage[Header.size] = newValue.rawValue
            }
        }
        
        var cursorId: Int64 {
            get {
                return storage[Header.size &+ 4]
            }
            set {
                storage[Header.size &+ 4] = newValue
            }
        }
        
        var startingFrom: Int32 {
            get {
                return storage[Header.size &+ 12]
            }
            set {
                storage[Header.size &+ 12] = newValue
            }
        }
        
        var numberReturned: Int32 {
            get {
                return storage[Header.size &+ 16]
            }
            set {
                storage[Header.size &+ 16] = newValue
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
