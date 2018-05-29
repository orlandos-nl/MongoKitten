import BSON
import NIO

public struct CountCommand: MongoDBCommand {
    typealias Reply = CountReply
    
    internal var namespace: Namespace {
        return count
    }
    
    internal let count: Namespace
    public var query: Query?
    public var limit: Int?
    public var skip: Int?
//    public var readConcern: ReadConcern?
//    public var collation: Collation?
    
    static let writing = false
    static let emitsCursor = false
    
    public init(_ query: Query? = nil, in collection: Collection) {
        self.count = collection.reference
        self.query = query
    }
    
    public func execute(on connection: MongoDBConnection) -> EventLoopFuture<Int> {
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
