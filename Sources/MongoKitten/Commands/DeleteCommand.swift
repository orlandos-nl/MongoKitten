import BSON
import NIO

/// Specifies how many documents may be removed
public enum RemoveLimit: Int, Codable {
    /// All documents that match the query may be removed
    case all = 0
    
    /// Only the first document matching the query may be removed
    case one = 1
}

/// The delete command removes documents from a collection. A single delete command can contain multiple delete specifications. The command cannot operate on capped collections. The remove methods provided by the MongoDB drivers use this command internally.
///
/// - see: https://docs.mongodb.com/manual/reference/command/delete/index.html
public struct DeleteCommand: MongoDBCommand {
    typealias Reply = DeleteReply
    
    /// A single delete statement
    public struct Single: Encodable {
        private enum CodingKeys: String, CodingKey {
            case query = "q"
            case limit
        }
        
        /// The filter
        public var query: Query
        
        /// The remove limit
        public var limit: RemoveLimit
        
        /// - parameter query: The filter
        /// - parameter limit: The remove limit
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
    
    /// An array of one or more delete statements to perform in the collection.
    public var deletes: [Single]
    
    /// Optional. If true, then when a delete statement fails, return without performing the remaining delete statements. If false, then when a delete statement fails, continue with the remaining delete statements, if any. Defaults to true.
    public var ordered: Bool?
//    public var writeConcern: WriteConcern?
    
    static let writing = true
    static let emitsCursor = false
    
    /// - parameter deletes: See `DeleteCommand.deletes`
    /// - parameter collection: The collection
    public init(_ deletes: [Single], from collection: Collection) {
        self.delete = collection.namespace
        self.deletes = Array(deletes)
    }
}

/// The reply to a `DeleteCommand`
public struct DeleteReply: Codable, ServerReplyDecodable {
    private enum CodingKeys: String, CodingKey {
        case successfulDeletes = "n"
        case ok
    }
    
    /// The number of successful deletes
    public let successfulDeletes: Int?
    private let ok: Int
    
    /// `true` if the `DeleteCommand` was successful
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
