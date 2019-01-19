struct ListDatabases: AdministrativeMongoDBCommand {
    typealias Reply = ListDatabasesResponse
    
    var namespace: Namespace {
        return Namespace(to: "$cmd", inDatabase: "admin")
    }
    
    let listDatabases: Int32 = 1
    var filter: Document?
    
    init() {}
}

struct ListDatabasesResponse: ServerReplyDecodableResult {
    var isSuccessful: Bool { return true }
    
    let databases: [DatabaseDescription]
    let totalSize: Int
    
    func makeResult(on collection: Collection) throws -> [DatabaseDescription] {
        return databases
    }
}

struct DatabaseDescription: Codable {
    let name: String
    let sizeOnDisk: Int
    let empty: Bool
}
