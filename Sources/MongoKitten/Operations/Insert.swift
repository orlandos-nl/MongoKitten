import BSON
import NIO

public struct InsertCommand<C: Codable>: MongoDBCommand {
    public typealias Result = InsertReply
    
    internal var collectionReference: CollectionReference {
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
    
    @discardableResult
    public func execute(on connection: MongoDBConnection) throws -> EventLoopFuture<InsertCommand<C>.Result> {
        return connection.execute(command: self)
    }
}

public struct InsertReply: ServerReplyDecodable {
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
}
