import NIO

struct AnyMessage {
    
}

final class MessageWriter: MessageToByteEncoder {
    typealias OutboundIn = AnyMessage
    
    func encode(ctx: ChannelHandlerContext, data: AnyMessage, out: inout ByteBuffer) throws {
        
    }
}
