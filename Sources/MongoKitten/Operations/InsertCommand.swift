import BSON
import NIO

public struct InsertCommand: MongoDBCommand {
    typealias Reply = InsertReply
    
    internal var namespace: Namespace {
        return insert
    }
    
    internal let insert: Namespace
    public var documents: [Document]
    public var ordered: Bool?
    public var bypassDocumentValidation: Bool?
    
    static var writing: Bool {
        return true
    }
    
    static var emitsCursor: Bool {
        return false
    }
    
    public init(_ documents: [Document], into collection: Collection) {
        self.insert = collection.reference
        self.documents = Array(documents)
    }
    
    @discardableResult
    public func execute(on connection: Connection) -> EventLoopFuture<InsertReply> {
        return connection.execute(command: self)
    }
}

public struct InsertReply: ServerReplyDecodable {
    typealias Result = InsertReply
    
    enum CodingKeys: String, CodingKey {
        case successfulInserts = "n"
        case ok
        case errorMessage = "errmsg"
    }
    
    public let successfulInserts: Int?
    private let ok: Int
    public private(set) var errorMessage: String?
    
    public var isSuccessful: Bool {
        return ok == 1
    }
    
    var mongoKittenError: MongoKittenError {
        return MongoKittenError(.commandFailure, reason: nil)
    }
    
    func makeResult(on collection: Collection) -> InsertReply {
        return self
    }
}
