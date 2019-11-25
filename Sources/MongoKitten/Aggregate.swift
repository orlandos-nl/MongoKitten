import NIO
import MongoKittenCore
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
    internal var _comment: String?
    internal var _allowDiskUse: Bool?
    internal var _collation: Collation?
    internal var _readConcern: ReadConcern?
    
    public var eventLoop: EventLoop { return collection.eventLoop }
    
    public func allowDiskUse(_ allowDiskUse: Bool? = true) -> AggregateBuilderPipeline {
        var pipeline = self
        pipeline._allowDiskUse = allowDiskUse
        return pipeline
    }
    
    public func comment(_ comment: String?) -> AggregateBuilderPipeline {
        var pipeline = self
        pipeline._comment = comment
        return pipeline
    }
    
    public func collation(_ collation: Collation?) -> AggregateBuilderPipeline {
        var pipeline = self
        pipeline._collation = collation
        return pipeline
    }
    
    public func readConcern(_ readConcern: ReadConcern?) -> AggregateBuilderPipeline {
        var pipeline = self
        pipeline._readConcern = readConcern
        return pipeline
    }
    
    private func makeCommand() -> AggregateCommand {
        var documents = [Document]()
        documents.reserveCapacity(stages.count * 2)
        
        for stage in stages {
            documents.append(contentsOf: stage.stages)
        }
        
        var command = AggregateCommand(
            inCollection: collection.name,
            pipeline: documents
        )
        
        command.comment = _comment
        command.allowDiskUse = _allowDiskUse
        command.collation = _collation
        command.readConcern = _readConcern
        
        return command
    }
    
    public func getConnection() -> EventLoopFuture<MongoConnection> {
        return collection.pool.next(for: MongoConnectionPoolRequest(writable: writing))
    }
    
    public func execute() -> EventLoopFuture<FinalizedCursor<AggregateBuilderPipeline>> {
        let command = makeCommand()
        
        return getConnection().flatMap { connection in
            return connection.executeCodable(
                command,
                namespace: self.collection.database.commandNamespace,
                in: self.collection.transaction,
                sessionId: self.collection.sessionId ?? connection.implicitSessionId
            ).decode(CursorReply.self).map { cursor in
                let cursor = MongoCursor(
                    reply: cursor.cursor,
                    in: self.collection.namespace,
                    connection: connection,
                    session: connection.implicitSession,
                    transaction: self.collection.transaction
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
                self.collection.pool.logger.error("MongoDB Aggregate failed")
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
