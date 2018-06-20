import BSON
import NIO

public struct DistinctCommand: MongoDBCommand {
    typealias Reply = DistinctReply
    
    internal var namespace: Namespace {
        return distinct
    }
    
    internal let distinct: Namespace
    public var key: String
    public var query: Query?
    
    static var writing: Bool {
        return true
    }
    
    static var emitsCursor: Bool {
        return false
    }
    
    public init(onKey key: String, into collection: Collection) {
        self.distinct = collection.reference
        self.key = key
    }
    
    public func execute(on connection: Connection) -> EventLoopFuture<[Primitive]> {
        return connection.execute(command: self).mapToResult(for: connection[namespace])
    }
}

struct DistinctReply: ServerReplyDecodable {
    typealias Result = [Primitive]
    
    let ok: Int
    let values: Document
    
    var mongoKittenError: MongoKittenError {
        return MongoKittenError(.commandFailure, reason: nil)
    }
    
    var isSuccessful: Bool {
        return ok == 1
    }
    
    func makeResult(on collection: Collection) throws -> [Primitive] {
        return values.values
    }
}
