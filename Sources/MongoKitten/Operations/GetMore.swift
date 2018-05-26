import NIO

internal struct GetMore: MongoDBCommand {
    typealias Reply = GetMoreReply
    
    internal var namespace: Namespace {
        return collection
    }
    
    /// This variable _must_ be the first encoded value, so keep it above all others
    /// The cursor id
    internal let getMore: Int64
    let collection: Namespace
    var batchSize: Int?
    var maxTimeMS: Int? = 300_000 // 5 min
    
    init(cursorId: Int64, batchSize: Int?, on collection: Collection) {
        self.getMore = cursorId
        self.collection = collection.reference
        self.batchSize = batchSize
    }
    
    func execute(on connection: MongoDBConnection) -> EventLoopFuture<GetMoreReply> {
        return connection.execute(command: self)
    }
}

struct GetMoreReply: ServerReplyDecodable {
    struct CursorDetails : Codable {
        var id: Int64
        var ns: String
        var nextBatch: [Document]
    }
    
    var mongoKittenError: MongoKittenError
    
    internal let cursor: CursorDetails
    private let ok: Int
    
    public var isSuccessful: Bool {
        return ok == 1
    }
    
    func makeResult(on collection: Collection) throws -> GetMoreReply {
        return self
    }
}
