import MongoCore

public struct UpdateCommand: Encodable {
    public struct UpdateRequest: Encodable {
        private enum CodingKeys: String, CodingKey {
            case query = "q"
            case update = "u"
            case multi, collation, arrayFilters
        }
        
        public var query: Document
        public var update: Document
        public var multi: Bool?
        public var upsert: Bool?
        public var collation: Collation?
        public var arrayFilters: [Document]?
        
        public init(where query: Document, to newValue: Document) {
            self.query = query
            self.update = newValue
        }
        
        public init(where query: Document, setting: Document?, unsetting: Document?) {
            self.query = query
            self.update = [
                "$set": setting,
                "$unset": unsetting
            ]
        }
    }
    
    /// This variable _must_ be the first encoded value, so keep it above all others
    private let update: String
    public var collection: String { return update }
    
    public var updates: [UpdateRequest]
    public var ordered: Bool?
    public var writeConcern: WriteConcern?
    public var bypassDocumentValidation: Bool?
    
    public init(updates: [UpdateRequest], inCollection collection: String) {
        self.update = collection
        self.updates = updates
    }
}

public struct UpdateReply: Decodable, Error {
    private enum CodingKeys: String, CodingKey {
        case ok, writeErrors, writeConcernError, upserted
        case updatableCount = "n"
        case updatedCount = "nModified"
    }
    
    public let ok: Int
    public let updatableCount: Int
    public let updatedCount: Int
    public let upserted: [Document]?
    public let writeErrors: [MongoWriteError]?
    public let writeConcernError: WriteConcernError?
}

