public struct MongoNamespace {
    public let collectionName: String
    public let databaseName: String
    public var fullCollectionName: String {
        return databaseName + "." + collectionName
    }

    public init(to collection: String, inDatabase database: String) {
        self.collectionName = collection
        self.databaseName = database
    }
}
