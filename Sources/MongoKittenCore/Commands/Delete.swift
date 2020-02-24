import MongoCore
import NIO

/// The delete command removes documents from a collection. A single delete command can contain multiple delete specifications. The command cannot operate on capped collections. The remove methods provided by the MongoDB drivers use this command internally.
///
/// - see: https://docs.mongodb.com/manual/reference/command/delete/index.html
public struct DeleteCommand: Codable {
    /// Specifies how many documents may be removed
    public enum Limit: Int, Codable {
        /// All documents that match the query may be removed
        case all = 0
        
        /// Only the first document matching the query may be removed
        case one = 1
    }
    
    /// A single delete statement
    public struct Removal: Codable {
        private enum CodingKeys: String, CodingKey {
            case query = "q"
            case limit
        }
        
        /// The filter
        public var query: Document
        
        /// The remove limit
        public var limit: Limit
        
        /// - parameter query: The filter
        /// - parameter limit: The remove limit
        public init(where query: Document, limit: Limit = .one) {
            self.query = query
            self.limit = limit
        }
    }
    
    /// This variable _must_ be the first encoded value, so keep it above all others
    private let delete: String
    public var collection: String { delete }
    
    /// An array of one or more delete statements to perform in the collection.
    public var deletes: [Removal]
    
    /// Optional. If true, then when a delete statement fails, return without performing the remaining delete statements. If false, then when a delete statement fails, continue with the remaining delete statements, if any. Defaults to true.
    public var ordered: Bool?
    public var writeConcern: WriteConcern?
    
    /// - parameter deletes: See `DeleteCommand.deletes`
    /// - parameter collection: The collection
    public init(_ deletes: [Removal], fromCollection collection: String) {
        self.delete = collection
        self.deletes = deletes
    }
    
    /// - parameter deletes: See `DeleteCommand.deletes`
    /// - parameter collection: The collection
    public init(where query: Document, limit: Limit = .one, fromCollection collection: String) {
        self.deletes = [
            Removal(where: query, limit: limit)
        ]
        self.delete = collection
    }
}

/// The reply to a `DeleteCommand`
public struct DeleteReply: Decodable {
    private enum CodingKeys: String, CodingKey {
        case ok, writeErrors, writeConcernError
        case deletes = "n"
    }
    
    /// The number of successful deletes
    public let deletes: Int
    public let ok: Int
    public let writeErrors: [MongoWriteError]?
    public let writeConcernError: WriteConcernError?
}
