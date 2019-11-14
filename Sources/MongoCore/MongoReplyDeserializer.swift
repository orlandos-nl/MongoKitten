import Foundation
import BSON
import NIO
import Logging

/// A type capable of deserializing messages from MongoDB
public struct MongoServerReplyDeserializer {
    private var header: MongoMessageHeader?
    private var reply: MongoServerReply?
    let logger: Logger

    public mutating func takeReply() -> MongoServerReply? {
        if let reply = reply {
            self.reply = nil
            return reply
        }

        return nil
    }

    public init(logger: Logger) {
        self.logger = logger
    }

    /// Parses a buffer into a server reply
    ///
    /// Returns `.continue` if enough data was read for a single reply
    ///
    /// Sets `reply` to a the found ServerReply when done parsing it.
    /// It's replaced with a new reply the next successful iteration of the parser so needs to be extracted after each `parse` attempt
    ///
    /// Any remaining data left in the `buffer` needs to be left until the next interation, which NIO does by default
    public mutating func parse(from buffer: inout ByteBuffer) throws -> DecodingState {
        let header: MongoMessageHeader

        if let _header = self.header {
            header = _header
        } else {
            if buffer.readableBytes < MongoMessageHeader.byteSize {
                return .needMoreData
            }

            header = try buffer.assertReadMessageHeader()
        }

        guard header.messageLength - MongoMessageHeader.byteSize <= buffer.readableBytes else {
            self.header = header
            return .needMoreData
        }

        self.header = nil

        switch header.opCode {
        case .reply:
            // <= Wire Version 5
            self.reply = try .reply(OpReply(reading: &buffer, header: header))
        case .message:
            // >= Wire Version 6
            self.reply = try .message(OpMessage(reading: &buffer, header: header))
        default:
            logger.error("Mongo Protocol error: OpCode \(header.opCode) in reply is not supported")
            throw MongoProtocolParsingError(reason: .unsupportedOpCode)
        }

        self.header = nil
        return .continue
    }
}

fileprivate extension Optional {
    func assert() throws -> Wrapped {
        guard let `self` = self else {
            throw MongoOptionalUnwrapFailure()
        }
        
        return self
    }
}
