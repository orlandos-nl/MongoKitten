struct AdministrativeCommand<Command: Encodable>: MongoDBCommand {
    typealias Reply = OK
    typealias ErrorReply = OK
    
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
    let dropDatabase: Int = 1
    
    init() {}
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
