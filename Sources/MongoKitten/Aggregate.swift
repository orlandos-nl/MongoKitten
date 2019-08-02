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
    
    public func count() -> EventLoopFuture<Int> {
        struct Count: Decodable {
            let count: Int
        }
        
        var pipeline = self
        pipeline.stages.append(.count(to: "count"))
        pipeline.stages.append(.project("count"))
        return pipeline.decode(Count.self).firstResult().flatMapThrowing { count in
            guard let count = count else {
                throw MongoError(.queryFailure, reason: .cursorDrained)
            }
            
            return count.count
        }
    }
    
    public func out(toCollection collectionName: String) -> EventLoopFuture<Void> {
        var pipeline = self
        pipeline.stages.append(
            AggregateBuilderStage(document: [
                "$out": collectionName
            ])
        )
        pipeline.writing = true
        
        return pipeline.execute().map { _ in }
    }
}
