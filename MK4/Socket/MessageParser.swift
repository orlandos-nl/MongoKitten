import NIO

final class MessageParser: ByteToMessageDecoder {
    typealias InboundIn = Message.Reply
    
//    var state: ByteParserState<MessageParser>
//
//    enum ParsingState {
//        case unknownLength([UInt8])
//        case knownLength(buffer: Message.Buffer, accumulated: Int)
//    }
//
//    func decode(ctx: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
//        if let partial = partial {
//            switch partial {
//            case .unknownLength(var data):
//                let missing = 4 &- data.count
//
//                if buffer.count < missing {
//                    return Future(.uncompleted(.unknownLength(data + Array(buffer))))
//                }
//
//                data.append(contentsOf: buffer[..<missing])
//                let size = buffer.count &- missing
//
//                var _length: Int32 = 0
//                memcpy(&_length, buffer.baseAddress!, 4)
//                let length: Int = numericCast(_length)
//
//                let message = Message.Buffer(size: length)
//
//                memcpy(message.mutableBuffer!.baseAddress, &_length, 4)
//                memcpy(
//                    message.mutableBuffer!.baseAddress!.advanced(by: 4),
//                    buffer.baseAddress!.advanced(by: missing),
//                    min(buffer.count &- missing, length &- 4)
//                )
//
//                if size < length {
//                    return Future(.completed(consuming: length &- buffer.count, result: message))
//                } else {
//                    return Future(.uncompleted(.knownLength(buffer: message, accumulated: size)))
//                }
//            case .knownLength(let message, let accumulated):
//                let needed = message.buffer.count &- accumulated
//                let copy = min(needed, buffer.count)
//                memcpy(message.mutableBuffer!.baseAddress!.advanced(by: accumulated), buffer.baseAddress!, copy)
//
//                if copy < needed {
//                    return Future(.uncompleted(.knownLength(buffer: message, accumulated: accumulated &+ copy)))
//                }
//
//                return Future(.completed(consuming: copy, result: message))
//            }
//        } else {
//            if buffer.count < 4 {
//                return Future(.uncompleted(.unknownLength(Array(buffer))))
//            }
//
//            let length: Int = buffer.baseAddress!.withMemoryRebound(to: Int32.self, capacity: 1) { numericCast($0.pointee) }
//
//            let messageStart = buffer.baseAddress!.advanced(by: 4)
//
//            if buffer.count < length {
//                // Don't include length header
//                let messageSize = length
//
//                let accumulating = buffer.count
//
//                let message = Message.Buffer(size: messageSize)
//                memcpy(message.mutableBuffer!.baseAddress!, messageStart, accumulating)
//
//                return Future(.uncompleted(.knownLength(buffer: message, accumulated: buffer.count)))
//            } else {
//                let buffer = ByteBuffer(start: buffer.baseAddress, count: length)
//
//                return Future(.completed(consuming: length, result: Message.Buffer(buffer)))
//            }
//        }
//    }
}
