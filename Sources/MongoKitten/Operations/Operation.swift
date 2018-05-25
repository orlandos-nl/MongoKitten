import BSON
import NIO

protocol AnyMongoDBCommand: Encodable {
    var collectionReference: CollectionReference { get }
}

protocol MongoDBCommand: AnyMongoDBCommand {
    associatedtype Reply: ServerReplyInitializable
    
    func execute(on database: MongoDBConnection) -> EventLoopFuture<Reply.Result>
}

extension EventLoopFuture where T: ServerReplyInitializable {
    internal func mapToResult() -> EventLoopFuture<T.Result> {
        return self.thenThrowing { reply in
            return try reply.makeResult()
        }
    }
}

protocol ServerReplyInitializable {
    associatedtype Result
    
    init(reply: ServerReply) throws
    
    func makeResult() throws -> Result
}

protocol ServerReplyDecodable: Decodable, ServerReplyInitializable {
    var isSuccessful: Bool { get }
    var mongoKittenError: MongoKittenError { get }
}

extension ServerReplyDecodable {
    init(reply: ServerReply) throws {
        let doc = try reply.documents.assertFirst()
        
        self = try BSONDecoder().decode(Self.self, from: doc)
        
        guard self.isSuccessful else {
            throw self.mongoKittenError
        }
    }
}

fileprivate extension Array where Element == Document {
    func assertFirst() throws -> Document {
        return self.first!
    }
}
