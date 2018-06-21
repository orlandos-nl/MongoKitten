import BSON
import NIO

/// Counts the number of documents in a collection or a view. Returns a document that contains this count and as well as the command status.
///
/// - see: https://docs.mongodb.com/manual/reference/command/count/index.html
public struct CountCommand: MongoDBCommand {
    typealias Reply = CountReply
    
    internal var namespace: Namespace {
        return count
    }
    
    internal let count: Namespace
    
    /// Optional. A query that selects which documents to count in the collection or view.
    public var query: Query?
    
    /// Optional. The maximum number of matching documents to return.
    public var limit: Int?
    
    /// Optional. The number of matching documents to skip before returning results.
    public var skip: Int?
//    public var readConcern: ReadConcern?
//    public var collation: Collation?
    
    static let writing = false
    static let emitsCursor = false
    
    /// - parameter query: The query
    /// - parameter collection: The collection
    public init(_ query: Query? = nil, in collection: Collection) {
        self.count = collection.reference
        self.query = query
    }
    
    /// Executes the count command on the given connection
    public func execute(on connection: Connection) -> EventLoopFuture<Int> {
        let collection = connection[self.namespace]
        
        return connection.execute(command: self).mapToResult(for: collection)
    }
}

struct CountReply: ServerReplyDecodable {
    let n: Int
    let ok: Int
    
    var isSuccessful: Bool {
        return ok == 1
    }
    
    var mongoKittenError: MongoKittenError {
        return MongoKittenError(.commandFailure, reason: nil)
    }
    
    func makeResult(on collection: Collection) -> Int {
        return n
    }
}
