import BSON
import MongoCore

public struct FindCommand: Codable {
    /// This variable _must_ be the first encoded value, so keep it above all others
    private let find: String
    public var collection: String { return find }

    public var filter: Document?
    public var sort: Document?
    public var projection: Document?
    public var skip: Int?
    public var limit: Int?
    public var batchSize: Int?
    public var readConcern: ReadConcern?
    public var collation: Collation?

    public init(filter: Document?, inCollection collection: String) {
        self.filter = filter
        self.find = collection
    }
}
