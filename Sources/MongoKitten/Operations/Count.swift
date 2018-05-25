import BSON
import NIO

public struct CountCommand: MongoDBCommand {
    typealias Reply = CountReply
    
    internal var collectionReference: CollectionReference {
        return count
    }
    
    internal let count: CollectionReference
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
        return connection.execute(command: self).mapToResult()
    }
}

struct CountReply: ServerReplyDecodable {
    let n: Int
    let ok: Int
    
    var isSuccessful: Bool {
        return ok == 1
    }
    
    var mongoKittenError: MongoKittenError {
        fatalError()
    }
    
    func makeResult() -> Int {
        return n
    }
}
