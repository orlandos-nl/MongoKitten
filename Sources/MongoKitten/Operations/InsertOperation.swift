import BSON
import NIO

public struct InsertCommand<C: Codable>: MongoDBCommand {
    public typealias Result = InsertReply
    
    var collectionReference: CollectionReference {
        return insert
    }
    
    public let insert: CollectionReference
    public var documents: [C]
    public var ordered: Bool?
    public var bypassDocumentValidation: Bool?
    
    static var writing: Bool {
        return true
    }
    
    static var emitsCursor: Bool {
        return false
    }
    
    public init(_ documents: [C], into collection: CollectionReference) {
        self.insert = collection
        self.documents = Array(documents)
    }
    
    public func execute(on database: MongoDBConnection) throws -> EventLoopFuture<InsertCommand<C>.Result> {
        return database.execute(command: self)
    }
}

public struct InsertReply: ServerReplyDecodable {
    enum CodingKeys: String, CodingKey {
        case n, ok, errorMessage = "errmsg"
    }
    
    private var n: Int?
    private var ok: Int
    public private(set) var errorMessage: String?
    
    public var isSuccessful: Bool {
        return ok == 1
    }
    
    var mongoKittenError: MongoKittenError {
        fatalError()
    }
}
