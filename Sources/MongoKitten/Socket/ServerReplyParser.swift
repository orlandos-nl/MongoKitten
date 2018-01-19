import Async
import Bits
import Foundation

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
                    
                    let message = Message.Buffer(size: messageSize)
                    memcpy(message.mutableBuffer!.baseAddress!, pointer, size)
                    
                    return Future(.uncompleted(.knownLength(buffer: message, accumulated: size)))
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
                
                return Future(.completed(consuming: copy, result: message))
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
                
                let message = Message.Buffer(size: messageSize)
                memcpy(message.mutableBuffer!.baseAddress!, messageStart, accumulating)
                
                return Future(.uncompleted(.knownLength(buffer: message, accumulated: accumulating)))
            } else {
                let buffer = ByteBuffer(start: buffer.baseAddress!.advanced(by: 4), count: length &- 4)
                
                return Future(.completed(consuming: length, result: Message.Buffer(buffer)))
            }
        }
    }
}
