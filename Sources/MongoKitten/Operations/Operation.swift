import BSON
import NIO

protocol AnyMongoDBCommand: Encodable {
    var collectionReference: CollectionReference { get }
}

protocol MongoDBCommand: AnyMongoDBCommand {
    associatedtype Result: ServerReplyInitializable
    
    func execute(on database: MongoDBConnection) throws -> EventLoopFuture<Result>
}

protocol ServerReplyInitializable {
    init(reply: ServerReply) throws
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
