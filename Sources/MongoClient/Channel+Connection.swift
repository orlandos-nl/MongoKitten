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

            guard let reply = parser.takeReply(), context.handleReply(reply) else {
                print("Reply received from MongoDB, but no request was waiting for the result.")
                return result
            }

            print(result, reply)
            return result
        } catch {
            print("error", error)
            self.context.cancelQueries(error)
            self.context.didError = true
            throw error
        }
    }

    mutating func decodeLast(context ctx: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        print(buffer.readableBytes, "last")
        return try decode(context: ctx, buffer: &buffer)
    }

    // TODO: this does not belong here but on the next handler
    func errorCaught(context ctx: ChannelHandlerContext, error: Error) {
        // So that it can take the remaining queries and re-try them
        print("error", error)
        ctx.close(promise: nil)
    }
}
