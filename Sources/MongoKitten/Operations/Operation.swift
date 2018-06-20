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
