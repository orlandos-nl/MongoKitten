struct AdministrativeCommand<Command: Encodable>: AdministrativeMongoDBCommand {
    typealias Reply = OK
    
    var namespace: Namespace
    let command: Command
    
    func encode(to encoder: Encoder) throws {
        try command.encode(to: encoder)
    }
    
    init(command: Command, on collection: Collection) {
        self.namespace = collection.namespace
        self.command = command
    }
}

struct DropDatabase: Encodable {
    private let dropDatabase: Int = 1
    
    init() {}
}

struct DropCollection: Encodable {
    private enum CodingKeys: String, CodingKey {
        case collection = "drop"
        case writeConcern
    }
    
    let collection: String
    var writeConcern: WriteConcern?
    
    init(named name: String) {
        self.collection = name
    }
}

struct OK: ServerReplyDecodableResult {
    typealias Result = Void
    
    let ok: Int
    
    var isSuccessful: Bool {
        return ok == 1
    }
    
    func makeResult(on collection: Collection) throws -> Void {
        return
    }
}
