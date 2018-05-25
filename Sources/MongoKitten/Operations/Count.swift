import BSON
import NIO

public struct Count: MongoDBCommand {
    typealias Reply = CountReply
    
    internal var collectionReference: CollectionReference {
        return count
    }
    
    internal let count: CollectionReference
    public var query: Query?
    public var skip: Int?
    public var limit: Int?
//    public var readConcern: ReadConcern?
//    public var collation: Collation?
    
    static var writing: Bool { return false }
    static var emitsCursor: Bool { return false }
    
    public init(_ query: Query? = nil, in collection: Collection) {
        self.count = collection.reference
        self.query = query
    }
    
    @discardableResult
    public func execute(on connection: MongoDBConnection) -> EventLoopFuture<Int> {
        return connection.execute(command: self).mapToResult()
    }
}

struct CountReply: ServerReplyDecodable {
    var n: Int
    var ok: Int
    
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
