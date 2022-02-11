import BSON
import MongoCore

public struct CreateIndexes: Encodable {
    public struct Index: Encodable {
        private enum CodingKeys: String, CodingKey {
            case name, key, unique, partialFilterExpression, sparse
            case expireAfterSeconds, storageEngine, weights
            case defaultLanguage = "default_language"
            case languageOverride = "language_override"
            case textIndexVersion
            case sphere2dIndexVersion = "2dsphereIndexVersion"
            case bits, min, max, bucketSize
        }
        
        // MARK: all indexes
        
        public var name: String
        public var key: Document
        public var unique: Bool?
        public var partialFilterExpression: Bool?
        public var sparse: Bool?
        public var expireAfterSeconds: Int?
        public var storageEngine: Document?
        public var collation: Collation?
        
        public init(named name: String, keys: Document) {
            self.name = name
            self.key = keys
        }
        
        public init(named name: String, key: String, order: Sorting.Order) {
            self.name = name
            self.key = [
                key: order.rawValue
            ]
        }
        
        // MARK: text indexes
        
        public var weights: Document?
        public var defaultLanguage: String?
        public var languageOverride: String?
        public var textIndexVersion: Int?
        
        // MARK: 2dsphere indexes

        public var sphere2dIndexVersion: Int?
        public var bits: Int?
        public var min: Int?
        public var max: Int?
        
        // MARK: geoHaystack indexes
        public var bucketSize: Int?
    }
    
    private let createIndexes: String
    public var collectionName: String {
        return createIndexes
    }
    public var indexes: [Index]
    public var writeConcern: WriteConcern?
    
    public init(collection: String, indexes: [Index]) {
        self.createIndexes = collection
        self.indexes = indexes
    }
}
