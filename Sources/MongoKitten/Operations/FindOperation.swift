import NIO

public struct FindOperation: MongoDBCommand {
    typealias Reply = CursorReply
    
    
    internal var namespace: Namespace {
        return find
    }
    
    /// This variable _must_ be the first encoded value, so keep it above all others
    internal let find: Namespace
    
    public var filter: Query?
    
    public init(filter: Query?, on collection: Collection) {
        self.filter = filter
        self.find = collection.reference
    }
}

struct CursorReply: ServerReplyDecodable {
    struct CursorDetails : Codable {
        var id: Int64
        var ns: String
        var firstBatch: [Document]
    }
    
    var mongoKittenError: MongoKittenError {
        return MongoKittenError(.commandFailure, reason: nil)
    }
    
    internal let cursor: CursorDetails
    private let ok: Int
    
    public var isSuccessful: Bool {
        return ok == 1
    }
    
    func makeResult(on collection: Collection) throws -> Cursor<Document> {
        return try Cursor(self, collection: collection)
    }
}
