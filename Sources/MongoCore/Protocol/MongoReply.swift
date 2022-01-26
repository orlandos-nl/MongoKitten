import BSON
import NIO

public enum MongoServerReply: Sendable {
    case reply(OpReply)
    case message(OpMessage)
    
    public var responseTo: Int32 {
        switch self {
        case .message(let message):
            return message.header.responseTo
        case .reply(let reply):
            return reply.header.responseTo
        }
    }
    
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
