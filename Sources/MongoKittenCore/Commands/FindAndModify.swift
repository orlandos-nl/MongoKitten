import BSON
import MongoCore

/// Implements https://docs.mongodb.com/manual/reference/command/findAndModify/
public struct FindAndModifyCommand: Codable, Sendable {
    /// The collection against which to run the command.
    public private(set) var findAndModify: String
    /// The selection criteria for the modification.
    public var query: Document?
    /// Determines which document the operation modifies if the query selects multiple documents. `findAndModify` modifies the first document in the sort order specified by this argument.
    public var sort: Document?
    /// Removes the document specified in the `query` field. Set this to `true` to remove the selected document . The default is `false`.
    public var remove: Bool
    /**
     Performs an update of the selected document.
     
     * If passed a document with update operator expressions, `findAndModify` performs the specified modification.
     * If passed a replacement document `{ <field1>: <value1>, ...}`, the `findAndModify` performs a replacement.
     * Starting in MongoDB 4.2, if passed an aggregation pipeline `[ <stage1>, <stage2>, ... ]`, `findAndModify` modifies the document per the pipeline. The pipeline can consist of the following stages:
        * `$addFields` and its alias `$set`
        * `$project` and its alias `$unset`
        * `$replaceRoot` and its alias `$replcaeWith`
     */
    public var update: Document?
    /// When true, returns the modified document rather than the original. The findAndModify method ignores the new option for remove operations.
    public var new: Bool?
    /// A subset of fields to return. The `fields` document specifies an inclusion of a field with `1`, as in: `fields: { <field1>: 1, <field2>: 1, ... }`. [See projection](https://docs.mongodb.com/manual/tutorial/project-fields-from-query-results/#read-operations-projection).
    public var fields: Document?
    /**
     Used in conjuction with the update field.
     
     When true, `findAndModify()` either:
     
     * Creates a new document if no documents match the `query`. For more details see [upsert behavior](https://docs.mongodb.com/manual/reference/method/db.collection.update/#upsert-behavior).
     * Updates a single document that matches `query`.
    
     To avoid multiple upserts, ensure that the query fields are uniquely indexed.
     */
    public var upsert: Bool?
    /// Enables findAndModify to bypass document validation during the operation. This lets you update documents that do not meet the validation requirements.
    public var bypassDocumentValidation: Bool?
    /**
     A document expressing the write concern. Omit to use the default write concern.
        
     Do not explicitly set the write concern for the operation if run in a transaction. To use write concern with transactions, see [Transactions and Write Concern](https://docs.mongodb.com/manual/core/transactions/#transactions-write-concern).
     */
    public var writeConcern: WriteConcern?
    /// Specifies a time limit in milliseconds for processing the operation.
    public var maxTimeMS: Int?
    /// Specifies the collation to use for the operation.
    public var collation: Collation?
    /// An array of filter documents that determine which array elements to modify for an update operation on an array field.
    public var arrayFilters: [Document]?
    
    public init(collection: String,
                query: Document? = nil,
                sort: Document? = nil,
                remove: Bool = false,
                update: Document? = nil,
                new: Bool? = nil,
                fields: Document? = nil,
                upsert: Bool? = nil,
                bypassDocumentValidation: Bool? = nil,
                writeConcern: WriteConcern? = nil,
                maxTimeMS: Int? = nil,
                collation: Collation? = nil,
                arrayFilters: [Document]? = nil) {
        self.findAndModify = collection
        self.query = query
        self.sort = sort
        self.remove = remove
        self.update = update
        self.new = new
        self.fields = fields
        self.upsert = upsert
        self.bypassDocumentValidation = bypassDocumentValidation
        self.writeConcern = writeConcern
        self.maxTimeMS = maxTimeMS
        self.collation = collation
        self.arrayFilters = arrayFilters
    }
}

public struct FindAndModifyReply: Codable, Error, Sendable {
    private enum CodingKeys: String, CodingKey {
        case ok
        case value
        case lastErrorObject
    }
    
    /// Contains the command’s execution status. `1` on success, or `0` if an error occurred.
    public let ok: Int
    /**
     Contains the command’s returned value.
     
     For `remove` operations, `value` contains the removed document if the query matches a document. If the query does not match a document to remove, `value` contains `nil`.
     For update operations, the value embedded document contains the following:
     * If the `new` parameter is not set or is `false`:
        * the pre-modification document if the query matches a document;
        * otherwise, `nil`.
     
     * if `new` is `true`:
        * the modified document if the query returns a match;
        * the inserted document if `upsert: true` and no document matches the query;
        * otherwise, `nil`.
     */
    public let value: Document?
    /// Contains information about updated documents.
    public let lastErrorObject: Document?
}

public enum FindAndModifyReturnValue: String, Codable, Sendable {
    /// Return the modified Document.
    case modified
    /// Return the original Document.
    case original
}
