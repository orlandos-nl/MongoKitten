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
            guard reply.isSuccessful else {
                throw reply
            }
            
            return try reply.makeResult(on: collection)
        }
    }
}

extension Document {
    func makeError() -> Error {
        do {
            let errorReply = try BSONDecoder().decode(ErrorReply.self, from: self)
            return MongoKittenError(errorReply)
        } catch {
            return error
        }
    }
}

protocol ServerReplyInitializable: Error {
    associatedtype Result
    
    init(reply: ServerReply) throws
    
    var isSuccessful: Bool { get }
    
    func makeResult(on collection: Collection) throws -> Result
}

protocol ServerReplyDecodable: Decodable, ServerReplyInitializable {}

extension ServerReplyDecodable {
    init(reply: ServerReply) throws {
        let doc = try reply.documents.assertFirst()
        
        if let ok: Double = doc.ok, ok < 1 {
            throw doc.makeError()
        } else if let ok: Int = doc.ok, ok < 1 {
            throw doc.makeError()
        } else if let ok: Int32 = doc.ok, ok < 1 {
            throw doc.makeError()
        }
        
        do {
            self = try BSONDecoder().decode(Self.self, from: doc)
        } catch {
            print(Self.self)
            throw error
        }
    }
}

extension Array where Element == Document {
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
    
    var isSuccessful: Bool {
        return ok == 1
    }
    
    private enum CodingKeys: String, CodingKey {
        case ok, code, codeName
        case errorMessage = "errmsg"
    }
    
    func makeResult(on collection: Collection) throws -> ErrorReply {
        return self
    }
}
