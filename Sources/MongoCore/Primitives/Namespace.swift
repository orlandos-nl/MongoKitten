public struct MongoNamespace: Codable, Sendable {
    public let collectionName: String
    public let databaseName: String
    public var fullCollectionName: String {
        return databaseName + "." + collectionName
    }

    public init(to collection: String, inDatabase database: String) {
        self.collectionName = collection
        self.databaseName = database
    }
    
    public func encode(to encoder: Encoder) throws {
        try fullCollectionName.encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        struct InvalidNamespace: Error {}
        
        let namespace = try decoder.singleValueContainer().decode(String.self)
        let values = namespace.split(separator: ".", maxSplits: 1)
        
        guard values.count == 2 else {
            throw InvalidNamespace()
        }
        
        self.init(to: String(values[1]), inDatabase: String(values[0]))
    }
}
