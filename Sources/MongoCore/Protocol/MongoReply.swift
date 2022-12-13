import BSON
import NIO

/// A reply from the server
public enum MongoServerReply: Sendable {
    /// A reply from the server, used for legacy wire protocols
    case reply(OpReply)

    /// A reply from the server, used for modern wire protocols
    case message(OpMessage)
    
    /// The request id this reply is in response to, used to match replies to requests
    public var responseTo: Int32 {
        switch self {
        case .message(let message):
            return message.header.responseTo
        case .reply(let reply):
            return reply.header.responseTo
        }
    }
    
    /// The body of the reply
    public var documents: [Document] {
        switch self {
        case .message(let message):
            var documents = [Document]()
            
            for section in message.sections {
                switch section {
                case .body(let document):
                    documents.append(document)
                case .sequence(let sequence):
                    documents.append(contentsOf: sequence.documents)
                }
            }
            
            return documents
        case .reply(let reply):
            return reply.documents
        }
    }
}
