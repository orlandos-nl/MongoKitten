import BSON
import NIO

public enum RemoveLimit: Int, Codable {
    case all = 0
    case one = 1
}

public struct DeleteCommand: MongoDBCommand {
    public typealias Reply = DeleteReply
    
    public struct Single: Encodable {
        public var q: Query
        public var limit: RemoveLimit
//        public var collation: Collation?
        
        public init(matching query: Query, limit: RemoveLimit = .one) {
            self.q = query
            self.limit = limit
        }
    }
    
    internal var collectionReference: CollectionReference {
        return delete
    }
    
    public let delete: CollectionReference
    public var deletes: [Single]
    public var ordered: Bool?
//    public var writeConcern: WriteConcern?
    public var bypassDocumentValidation: Bool?
    
    static var writing: Bool { return true }
    static var emitsCursor: Bool { return false }
    
    public init(_ deletes: [Single], from collection: Collection) {
        self.delete = collection.reference
        self.deletes = Array(deletes)
    }
    
    @discardableResult
    public func execute(on connection: MongoDBConnection) -> EventLoopFuture<Int> {
        return connection.execute(command: self).mapToResult()
    }
}

public struct DeleteReply: Codable, ServerReplyDecodable {
    enum CodingKeys: String, CodingKey {
        case successfulDeletes = "n"
        case ok
    }
    
    public let successfulDeletes: Int?
    private let ok: Int
    
    public var isSuccessful: Bool {
        return ok == 1
    }
    
    var mongoKittenError: MongoKittenError {
        fatalError()
    }
    
    func makeResult() throws -> Int {
        guard let successfulDeletes = successfulDeletes else {
            unimplemented()
        }
        
        return successfulDeletes
    }
//    public var writeErrors: [Errors.Write]?
//    public var writeConcernError: [Errors.WriteConcern]?
}

