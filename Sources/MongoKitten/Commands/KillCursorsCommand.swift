internal struct KillCursorsCommand: AdministrativeMongoDBCommand {
    typealias Reply = KillCursorsReply
    
    var namespace: Namespace {
        return killCursors
    }
    
    let killCursors: Namespace
    var cursors: [Int64]
    
    init(_ cursors: [Int64], in namespace: Namespace) {
        self.killCursors = namespace
        self.cursors = cursors
    }
}

struct KillCursorsReply: ServerReplyDecodableResult {
    typealias Result = KillCursorsReply
    
    let cursorsKilled: [Int64]
    let cursorsAlive: [Int64]
    let ok: Int
    
    func makeResult(on collection: Collection) throws -> KillCursorsReply {
        return self
    }
    
    var isSuccessful: Bool { return ok == 1 }
}
