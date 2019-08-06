import NIO

internal struct GetMore: AdministrativeMongoDBCommand {
    typealias Reply = GetMoreReply
    
    internal var namespace: Namespace {
        return collection
    }
    
    /// This variable _must_ be the first encoded value, so keep it above all others
    /// The cursor id
    internal let getMore: Int64
    let collection: Namespace
    var batchSize: Int?
    var readConcern: ReadConcern?
    
    init(cursorId: Int64, batchSize: Int?, on collection: Collection) {
        self.getMore = cursorId
        self.collection = collection.namespace
        self.batchSize = batchSize
    }
}

struct GetMoreReply: ServerReplyDecodable, ServerReplyInitializableResult {
    struct CursorDetails: Codable {
        var id: Int64
        var ns: String
        var nextBatch: [Document]
    }
    
    internal let cursor: CursorDetails
    private let ok: Int
    
    var isSuccessful: Bool {
        return ok == 1
    }
    
    func makeResult(on collection: Collection) throws -> GetMoreReply {
        return self
    }
}
