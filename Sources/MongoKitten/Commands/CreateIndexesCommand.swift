import BSON

public struct CreateIndexesCommand: MongoDBCommand {
    typealias Reply = CreateIndexesReply
    internal var namespace: Namespace { return createIndexes }
    
    internal let createIndexes: Namespace
    public var indexes: [Index]
    
    // public var writeConcern: WriteConcern?
    
    public init(_ indexes: [Index], for collection: Collection) {
        self.indexes = indexes
        self.createIndexes = collection.namespace
    }
}

struct CreateIndexesReply: Codable, ServerReplyDecodable {
    func makeResult(on collection: Collection) throws -> Void {}
    
    typealias Result = Void
    
    var isSuccessful: Bool { return ok == 1 }
    
    var mongoKittenError: MongoKittenError {
        return MongoKittenError(.commandFailure, reason: .indexCreationFailed)
    }
    
    private let ok: Int
    private let errmsg: String?
    private let code: Int?
//    private let note: - only exists when an existing index was in place
}
