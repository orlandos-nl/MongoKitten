struct AdministrativeCommand<Command: Encodable>: MongoDBCommand {
    typealias Reply = OK
    
    var namespace: Namespace
    let command: Command
    
    func encode(to encoder: Encoder) throws {
        try command.encode(to: encoder)
    }
    
    init(command: Command, on collection: Collection) {
        self.namespace = collection.reference
        self.command = command
    }
}

struct DropDatabase: Encodable {
    let dropDatabase: Int = 1
    
    init() {}
}

struct OK: ServerReplyDecodable {
    typealias Result = Bool
    
    var mongoKittenError: MongoKittenError {
        return MongoKittenError(.commandFailure, reason: nil)
    }
    
    let ok: Int
    
    var isSuccessful: Bool {
        return ok == 1
    }
    
    func makeResult(on collection: Collection) throws -> Bool {
        return isSuccessful
    }
}
