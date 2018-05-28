import BSON
import NIO

public struct AggregateCommand: MongoDBCommand {
    typealias Reply = CursorReply
    
    internal var namespace: Namespace {
        return aggregate
    }
    
    internal let aggregate: Namespace
    public var pipeline: [Document]
    public var cursor = CursorSettings()
    
    static let writing = false
    static let emitsCursor = true
    
    public init<O>(pipeline: Pipeline<O>, in collection: Collection) {
        self.aggregate = collection.reference
        self.pipeline = pipeline.stages
    }
    
    public func execute(on connection: MongoDBConnection) -> EventLoopFuture<Cursor<Document>> {
        let collection = connection[self.namespace]
        
        return connection.execute(command: self).mapToResult(for: collection)
    }
}
