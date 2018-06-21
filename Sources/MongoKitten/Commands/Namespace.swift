internal struct Namespace: Encodable {
    public let collectionName: String
    public let databaseName: String
    public var fullCollectionName: String {
        return databaseName + "." + collectionName
    }
    
    internal init(to collection: String, inDatabase database: String) {
        self.collectionName = collection
        self.databaseName = database
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(collectionName)
    }
}
