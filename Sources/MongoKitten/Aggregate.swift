import NIO
import MongoClient

extension MongoCollection {
    public func aggregate(_ stages: [AggregateBuilderStage]) -> AggregateBuilderPipeline {
        var pipeline = AggregateBuilderPipeline(stages: stages)
        pipeline.collection = self
        return pipeline
    }
}

public struct AggregateBuilderPipeline: QueryCursor {
    public typealias Element = Document
    internal var collection: MongoCollection!
    internal var writing = false
    
    public var eventLoop: EventLoop { collection.eventLoop }
    
    private func makeCommand() -> AggregateCommand {
        var documents = [Document]()
        documents.reserveCapacity(stages.count * 2)
        
        for stage in stages {
            documents.append(contentsOf: stage.stages)
        }
        
        return AggregateCommand(inCollection: collection.name, pipeline: documents)
    }
    
    public func getConnection() -> EventLoopFuture<MongoConnection> {
        return collection.pool.next(for: MongoConnectionPoolRequest(writable: writing))
    }
    
    public func execute() -> EventLoopFuture<FinalizedCursor<AggregateBuilderPipeline>> {
        let command = makeCommand()
        
        return getConnection().flatMap { connection in
            return connection.executeCodable(
                command,
                namespace: self.collection.database.commandNamespace
            ).decode(CursorReply.self).map { cursor in
                let cursor = MongoCursor(
                    reply: cursor.cursor,
                    in: self.collection.namespace,
                    connection: connection
                )
                return FinalizedCursor(basedOn: self, cursor: cursor)
            }
        }
    }
    
    public func transformElement(_ element: Document) throws -> Document {
        return element
    }
    
    var stages: [AggregateBuilderStage]
    
    internal init(stages: [AggregateBuilderStage]) {
        self.stages = stages
    }
}

public struct AggregateBuilderStage {
    var stages: [Document]
    
    public init(document: Document) {
        self.stages = [document]
    }
    
    init(documents: [Document]) {
        self.stages = documents
    }
    
    public static func match(_ query: Document) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$match": query
        ])
    }
    
    public static func project(_ projection: Projection) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$project": projection.document
        ])
    }
    
    public static func skip(_ n: Int) -> AggregateBuilderStage {
        assert(n > 0)
        
        return AggregateBuilderStage(document: [
            "$skip": n
        ])
    }
    
    public static func limit(_ n: Int) -> AggregateBuilderStage {
        assert(n > 0)
        
        return AggregateBuilderStage(document: [
            "$limit": n
        ])
    }
    
    public static func sample(_ n: Int) -> AggregateBuilderStage {
        assert(n > 0)
        
        return AggregateBuilderStage(document: [
            "$sample": n
        ])
    }
}
