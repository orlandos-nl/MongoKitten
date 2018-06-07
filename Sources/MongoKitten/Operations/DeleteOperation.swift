import BSON
import NIO

public enum RemoveLimit: Int, Codable {
    case all = 0
    case one = 1
}

public struct DeleteCommand: MongoDBCommand {
    typealias Reply = DeleteReply
    
    public struct Single: Encodable {
        public enum CodingKeys: String, CodingKey {
            case query = "q"
            case limit
        }
        
        public var query: Query
        public var limit: RemoveLimit
        
        public init(matching query: Query, limit: RemoveLimit = .one) {
            self.query = query
            self.limit = limit
        }
    }
    
    internal var namespace: Namespace {
        return delete
    }
    
    /// This variable _must_ be the first encoded value, so keep it above all others
    internal let delete: Namespace
    
    public var deletes: [Single]
    public var ordered: Bool?
//    public var writeConcern: WriteConcern?
    public var bypassDocumentValidation: Bool?
    
    static let writing = true
    static let emitsCursor = false
    
    public init(_ deletes: [Single], from collection: Collection) {
        self.delete = collection.reference
        self.deletes = Array(deletes)
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
        return MongoKittenError(.commandFailure, reason: nil)
    }
    
    func makeResult(on collection: Collection) throws -> Int {
        guard let successfulDeletes = successfulDeletes else {
            throw MongoKittenError(.commandFailure, reason: nil)
        }
        
        return successfulDeletes
    }
//    public var writeErrors: [Errors.Write]?
//    public var writeConcernError: [Errors.WriteConcern]?
}
