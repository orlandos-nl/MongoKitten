import NIO
import MongoCore

internal struct MongoContextOption: ChannelOption {
    internal typealias Value = MongoClientContext
}

internal struct ClientConnectionParser: ByteToMessageDecoder {
    typealias InboundOut = MongoServerReply

    private let context: MongoClientContext
    private var parser: MongoServerReplyDeserializer

    internal init(context: MongoClientContext) {
        self.context = context
        self.parser = MongoServerReplyDeserializer(logger: context.logger)
    }

    mutating func decode(context ctx: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        do {
            let result = try parser.parse(from: &buffer)

            if let reply = parser.takeReply() {
                Task { [context] in
                    if await !context.handleReply(reply) {
                        print("Reply received from MongoDB, but no request was waiting for the result.")
                    }
                }
            }

            return result
        } catch {
            Task { [context] in
                await context.cancelQueries(error)
            }
            
            throw error
        }
    }

    mutating func decodeLast(context ctx: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        return try decode(context: ctx, buffer: &buffer)
    }

    // TODO: this does not belong here but on the next handler
    func errorCaught(context ctx: ChannelHandlerContext, error: Error) {
        // So that it can take the remaining queries and re-try them
        ctx.close(promise: nil)
    }
}
