import NIO

public struct FindOperation: MongoDBCommand {
    typealias Reply = CursorReply
    
    internal var namespace: Namespace {
        return find
    }
    
    /// This variable _must_ be the first encoded value, so keep it above all others
    internal let find: Namespace
    
    public var filter: Query?
    public var sort: Sort?
    public var projection: Projection?
    public var skip: Int?
    public var limit: Int?
    
    public init(filter: Query?, on collection: Collection) {
        self.filter = filter
        self.find = collection.reference
    }
}

public struct CursorSettings: Encodable {
    var batchSize: Int?
}

struct CursorReply: ServerReplyDecodable {
    struct CursorDetails: Codable {
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
    
    func makeResult(on collection: Collection) throws -> Cursor {
        return Cursor(reply: self, in: collection)
    }
}

public final class FindCursor: QueryCursor {
    public typealias Element = Document
    
    public var batchSize = 101
    public let collection: Collection
    private var operation: FindOperation
    public private(set) var didExecute = false
    
    public init(operation: FindOperation, on collection: Collection) {
        self.operation = operation
        self.collection = collection
    }
    
    public func execute() -> EventLoopFuture<FinalizedCursor<FindCursor>> {
        return self.collection.connection.execute(command: self.operation).mapToResult(for: collection).map { cursor in
            return FinalizedCursor(basedOn: self, cursor: cursor)
        }
    }
    
    public func setBatchSize(_ batchSize: Int) -> FindCursor {
        self.batchSize = batchSize
        return self
    }
    
    public func transformElement(_ element: Document) throws -> Document {
        return element
    }
    
    public func limit(_ limit: Int) -> FindCursor {
        self.operation.limit = limit
        return self
    }
    
    public func skip(_ skip: Int) -> FindCursor {
        self.operation.skip = skip
        return self
    }
    
    public func project(_ projection: Projection) -> FindCursor {
        self.operation.projection = projection
        return self
    }
    
    public func sort(_ sort: Sort) -> FindCursor {
        self.operation.sort = sort
        return self
    }
}
