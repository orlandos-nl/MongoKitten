import BSON
import NIO

public struct DistinctCommand: ReadCommand {
    typealias Reply = DistinctReply
    
    internal var namespace: Namespace {
        return distinct
    }
    
    internal let distinct: Namespace
    public var key: String
    public var query: Query?
    public var readConcern: ReadConcern?
    
    static var writing: Bool {
        return true
    }
    
    static var emitsCursor: Bool {
        return false
    }
    
    public init(onKey key: String, into collection: Collection) {
        self.distinct = collection.namespace
        self.key = key
    }
}

struct DistinctReply: ServerReplyDecodableResult {
    typealias Result = [Primitive]
    
    let ok: Int
    let values: Document
    
    var isSuccessful: Bool {
        return ok == 1
    }
    
    func makeResult(on collection: Collection) throws -> [Primitive] {
        return values.values
    }
}
