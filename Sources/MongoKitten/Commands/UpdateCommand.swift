import BSON
import NIO

/// The update command modifies documents in a collection. A single update command can contain multiple update statements. The update methods provided by the MongoDB drivers use this command internally.
public struct UpdateCommand: WriteCommand {
    typealias Reply = UpdateReply
    
    /// A single update statement
    public struct Single: Encodable {
        public enum CodingKeys: String, CodingKey {
            case query = "q"
            case update = "u"
            case upsert
            case multiple = "multi"
        }
        
        /// The query that matches documents to update. Use the same query selectors as used in the find() method.
        public var query: Query
        
        /// The modifications to apply.
        public var update: Document
//        public var collation: Collation?
        
        /// Optional. If true, perform an insert if no documents match the query. If both upsert and multiple are true and no documents match the query, the update operation inserts only a single document.
        public var upsert: Bool?
        
        /// Optional. If true, updates all documents that meet the query criteria. If false, limit the update to one document that meet the query criteria. Defaults to false.
        public var multiple: Bool?
        
        /// - parameter query: The query that matches documents to update. Use the same query selectors as used in the find() method.
        /// - parameter document: The modifications to apply.
        /// - parameter multiple: If true, updates all documents that meet the query criteria. If false, limit the update to one document that meet the query criteria. Defaults to false.
        public init(matching query: Query, to document: Document, multiple: Bool? = nil) {
            self.query = query
            self.update = document
            self.multiple = multiple
        }
    }
    
    internal var namespace: Namespace {
        return update
    }
    
    private let update: Namespace
    
    /// An array of one or more update statements to perform in the collection.
    public var updates: [Single]
    
    /// Optional. If true, then when an update statement fails, return without performing the remaining update statements. If false, then when an update fails, continue with the remaining update statements, if any. Defaults to true.
    public var ordered: Bool?
    
    public var writeConcern: WriteConcern?
    
    /// Optional. Enables update to bypass document validation during the operation. This lets you update documents that do not meet the validation requirements.
    public var bypassDocumentValidation: Bool?
    
    static let writing = true
    static let emitsCursor = false
    
    /// - parameter query: The filter
    public init(_ query: Query, to document: Document, in collection: Collection, multiple: Bool? = nil) {
        self.init(
            Single(matching: query, to: document, multiple: multiple),
            in: collection
        )
    }
    
    /// - parameter updates: An array of one or more update statements to perform in the collection.
    /// - parameter collection: The collection
    public init(_ updates: Single..., in collection: Collection) {
        self.init(updates, in: collection)
    }
    
    /// - parameter updates: An array of one or more update statements to perform in the collection.
    /// - parameter collection: The collection
    public init(_ updates: [Single], in collection: Collection) {
        self.update = collection.namespace
        self.updates = Array(updates)
    }
    
    @discardableResult
    public func execute(on session: ClientSession) -> EventLoopFuture<UpdateReply> {
        return session.execute(command: self)
    }
}

public struct UpdateReply: ServerReplyDecodableResult {
    typealias Result = UpdateReply
    
    public enum CodingKeys: String, CodingKey {
        case updated = "n"
        case ok
        case modified = "nModified"
    }
    
    public let updated: Int?
    private let ok: Int
    public let modified: Int
//    public var upserted: [Document]? // TODO: type-safe? We cannot (easily) decode the _id
//    public var writeErrors: [Errors.Write]?
//    public var writeConcernError: [Errors.WriteConcern]?
    
    public var isSuccessful: Bool {
        return ok == 1
    }
    
    func makeResult(on collection: Collection) throws -> UpdateReply {
        return self
    }
}

/// Modifiers that are available for use in update operations.
///
/// - see: https://docs.mongodb.com/manual/reference/operator/update/
public enum UpdateOperator: Encodable {
    /// The $currentDate operator sets the value of a field to the current date, as a `Date`
    case currentDate(field: String)
    
    /// The $inc operator increments a field by a specified value.
    case increment(field: String, amount: Primitive)
    
    /// The $min updates the value of the field to a specified value if the specified value is less than the current value of the field. The $min operator can compare values of different types, using the BSON comparison order.
    case min(String, Primitive)
    
    /// The $max operator updates the value of the field to a specified value if the specified value is greater than the current value of the field. The $max operator can compare values of different types, using the BSON comparison order.
    case max(String, Primitive)
    
    /// Multiply the value of a field by a number.
    case multiply(String, Primitive)
    
    /// The $rename operator updates the name of a field
    case rename(field: String, to: String)
    
    /// Replaces the value of a field with the specified value
    case set(field: String, to: Primitive)
    
    /// Unsets the given field
    case unset(field: String)
    
    /// A custom update operator
    case custom(document: Document)
    
    public func encode(to encoder: Encoder) throws {
        let document: Document
        
        switch self {
        case .currentDate(let field):
            document = ["$currentDate": [field: true]]
        case .increment(let field, let amount):
            document = ["$inc": [field: amount] as Document]
        case .min(let field, let value):
            document = ["$min": [field: value] as Document]
        case .max(let field, let value):
            document = ["$max": [field: value] as Document]
        case .multiply(let field, let value):
            document = ["$mul": [field: value] as Document]
        case .rename(let field, let newName):
            document = ["$rename": [field: newName]]
        case .set(let field, let value):
            document = ["$set": [field: value] as Document]
        case .unset(let field):
            document = ["$unset": [field: ""]]
        case .custom(let spec):
            document = spec
        }
        
        try document.encode(to: encoder)
    }
}
