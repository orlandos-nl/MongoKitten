import BSON
import NIO

public struct InsertCommand<E: Encodable>: MongoDBCommand {
    typealias Reply = InsertReply
    
    internal var collectionReference: CollectionReference {
        return insert
    }
    
    internal let insert: CollectionReference
    public var documents: [E]
    public var ordered: Bool?
    public var bypassDocumentValidation: Bool?
    
    static var writing: Bool {
        return true
    }
    
    static var emitsCursor: Bool {
        return false
    }
    
    public init(_ documents: [E], into collection: Collection) {
        self.insert = collection.reference
        self.documents = Array(documents)
    }
    
    @discardableResult
    public func execute(on connection: MongoDBConnection) -> EventLoopFuture<InsertReply> {
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
        fatalError()
    }
    
    func makeResult() -> InsertReply {
        return self
    }
}
