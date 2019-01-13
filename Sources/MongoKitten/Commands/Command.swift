import BSON
import NIO

protocol AnyMongoDBCommand: Encodable {
    func checkValidity(for maxWireVersion: WireVersion) throws
    
    var namespace: Namespace { get }
}

protocol MongoDBCommand: AnyMongoDBCommand {
    associatedtype Reply: ServerReplyInitializableResult
    associatedtype ErrorReply: ServerReplyInitializable
    
    func execute(on session: ClientSession) -> EventLoopFuture<Reply.Result>
}

protocol AdministrativeMongoDBCommand: MongoDBCommand where ErrorReply == GenericErrorReply {}

extension AdministrativeMongoDBCommand {
    func checkValidity(for maxWireVersion: WireVersion) throws {}
}

protocol WriteCommand: MongoDBCommand where ErrorReply == WriteErrorReply {
    var writeConcern: WriteConcern? { get }
}

extension WriteCommand {
    func checkValidity(for maxWireVersion: WireVersion) throws {
        if !maxWireVersion.supportsWriteConcern, self.writeConcern != nil {
            throw MongoKittenError(.unsupportedFeatureByServer, reason: .writeConcernUnsupported)
        }
    }
}

protocol ReadCommand: MongoDBCommand where ErrorReply == ReadErrorReply {
    var readConcern: ReadConcern? { get }
}

extension ReadCommand {
    func checkValidity(for maxWireVersion: WireVersion) throws {
        if !maxWireVersion.supportsWriteConcern, self.readConcern != nil {
            throw MongoKittenError(.unsupportedFeatureByServer, reason: .readConcernUnsupported)
        }
    }
}

extension MongoDBCommand {
    func execute(on session: ClientSession) -> EventLoopFuture<Reply.Result> {
        return session.execute(command: self).mapToResult(for: session[self.namespace])
    }
}

extension EventLoopFuture where T: ServerReplyInitializableResult {
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
            let errorReply = try BSONDecoder().decode(GenericErrorReply.self, from: self)
            return MongoKittenError(errorReply)
        } catch {
            return error
        }
    }
}

protocol ServerReplyInitializable: Error {
    init(reply: ServerReply) throws
}

protocol ServerReplyInitializableResult: ServerReplyInitializable {
    associatedtype Result
    
    var isSuccessful: Bool { get }
    
    func makeResult(on collection: Collection) throws -> Result
}

protocol ServerReplyDecodable: Decodable, ServerReplyInitializable {}

typealias ServerReplyDecodableResult = ServerReplyDecodable & ServerReplyInitializableResult

extension ServerReplyDecodable {
    init(reply: ServerReply) throws {
        let doc = try reply.documents.assertFirst()
        
        if let ok = doc["ok"] as? Double, ok < 1 {
            throw doc.makeError()
        } else if let ok = doc["ok"] as? Int, ok < 1 {
            throw doc.makeError()
        } else if let ok = doc["ok"] as? Int32, ok < 1 {
            throw doc.makeError()
        }
        
        do {
            self = try BSONDecoder().decode(Self.self, from: doc)
        } catch {
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
public struct GenericErrorReply: ServerReplyDecodable, Encodable, Equatable {
    public let ok: Int
    public let errorMessage: String?
    public let code: Int?
    public let codeName: String?
    
    private enum CodingKeys: String, CodingKey {
        case ok, code, codeName
        case errorMessage = "errmsg"
    }
}

public protocol ErrorDocument: Codable {
    var code: Int { get }
    var errInfo: Document { get }
    var errmsg: String { get }
}

public struct WriteErrorDocument: ErrorDocument {
    public let code: Int
    public let errInfo: Document
    public let errmsg: String
    public let index: Int
}

public struct WriteErrorReply: ServerReplyDecodable, Encodable {
    typealias Result = WriteErrorReply
    
    public let ok: Int
    public let writeErrors: [WriteErrorDocument]?
    public let writeConcernError: WriteErrorDocument?
    public let errmsg: String
    
    internal let isSuccessful = false
    
    func makeResult(on collection: Collection) -> WriteErrorReply {
        return self
    }
}

public struct ReadErrorReply: ServerReplyDecodable {
    typealias Result = ReadErrorReply
    
    public let ok: Int
    public let errmsg: String
    public let code: Int
    let isSuccessful = false
    
    func makeResult(on collection: Collection) throws -> ReadErrorReply {
        return self
    }
}
