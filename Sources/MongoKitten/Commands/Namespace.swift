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

internal struct AdministrativeNamespace: Encodable {
    static let admin = AdministrativeNamespace(namespace: Namespace(to: "$cmd", inDatabase: "admin"))
    
    let namespace: Namespace
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Int32(1))
    }
}
