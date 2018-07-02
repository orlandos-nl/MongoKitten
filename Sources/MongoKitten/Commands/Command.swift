import BSON
import NIO

protocol AnyMongoDBCommand: Encodable {
    var namespace: Namespace { get }
}

protocol MongoDBCommand: AnyMongoDBCommand {
    associatedtype Reply: ServerReplyInitializable
    
    func execute(on connection: Connection) -> EventLoopFuture<Reply.Result>
}

extension MongoDBCommand {
    func execute(on connection: Connection) -> EventLoopFuture<Reply.Result> {
        return connection.execute(command: self).mapToResult(for: connection[self.namespace])
    }
}

extension EventLoopFuture where T: ServerReplyInitializable {
    internal func mapToResult(for collection: Collection) -> EventLoopFuture<T.Result> {
        return self.thenThrowing { reply in
            return try reply.makeResult(on: collection)
        }
    }
}

protocol ServerReplyInitializable {
    associatedtype Result
    
    init(reply: ServerReply) throws
    
    func makeResult(on collection: Collection) throws -> Result
}

protocol ServerReplyDecodable: Decodable, ServerReplyInitializable {}

extension ServerReplyDecodable {
    init(reply: ServerReply) throws {
        let doc = try reply.documents.assertFirst()
        
        if let ok: Double = doc.ok, ok < 1 {
            let errorReply = try BSONDecoder().decode(ErrorReply.self, from: doc)
            throw MongoKittenError(errorReply)
        }
        
        self = try BSONDecoder().decode(Self.self, from: doc)
    }
}

fileprivate extension Array where Element == Document {
    func assertFirst() throws -> Document {
        return self.first!
    }
}

/// A reply from the server, indicating an error
public struct ErrorReply: ServerReplyDecodable, Equatable, Encodable {
    typealias Result = ErrorReply
    
    public let ok: Int
    public let errorMessage: String?
    public let code: Int?
    public let codeName: String?
    
    private enum CodingKeys: String, CodingKey {
        case ok, code, codeName
        case errorMessage = "errmsg"
    }
    
    func makeResult(on collection: Collection) throws -> ErrorReply {
        return self
    }
}
