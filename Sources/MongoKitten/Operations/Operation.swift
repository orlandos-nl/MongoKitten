import BSON
import NIO

protocol AnyMongoDBCommand: Codable {
    var collectionName: String { get }
}

protocol MongoDBCommand: AnyMongoDBCommand {
    associatedtype Result: ServerReplyInitializable
    
    func execute(on database: MongoDBConnection) throws -> EventLoopFuture<Result>
}

protocol ServerReplyInitializable {
    init(reply: ServerReply) throws
}

protocol ServerReplyDecodable: Decodable, ServerReplyInitializable {}

extension ServerReplyDecodable {
    init(reply: ServerReply) throws {
        let doc = try reply.documents.assertFirst()
        
        self = try BSONDecoder().decode(Self.self, from: doc)
    }
}

fileprivate extension Array where Element == Document {
    func assertFirst() throws -> Document {
        return self.first!
    }
}
