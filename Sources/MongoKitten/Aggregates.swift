import MongoClient
import NIO

@_functionBuilder
public struct AggregateBuilder {
    /// If there are no children in an HTMLBuilder closure, then return an empty
    /// MultiNode.
    public static func buildBlock() -> AggregateBuilderPipeline {
        return AggregateBuilderPipeline(stages: [])
    }
    
    /// If there is one child, return it directly.
    public static func buildBlock(_ content: AggregateBuilderStage) -> AggregateBuilderPipeline {
        return AggregateBuilderPipeline(stages: [content])
    }
    
    /// If there are multiple children, return them all as a MultiNode.
    public static func buildBlock(_ content: AggregateBuilderStage...) -> AggregateBuilderPipeline {
        return AggregateBuilderPipeline(stages: content)
    }
    
    /// If the provided child is `nil`, build an empty MultiNode. Otherwise,
    /// return the wrapped value.
    public static func buildIf(_ content: AggregateBuilderStage?) -> AggregateBuilderPipeline {
        if let content = content { return AggregateBuilderPipeline(stages: [content]) }
        return AggregateBuilderPipeline(stages: [])
    }
    
    /// If the condition of an `if` statement is `true`, then this method will
    /// be called and the result of evaluating the expressions in the `true` block
    /// will be returned unmodified.
    /// - note: We do not need to preserve type information
    ///         from both the `true` and `false` blocks, so this function does
    ///         not wrap its passed value.
    public static func buildEither(first: AggregateBuilderStage) -> AggregateBuilderPipeline {
        return AggregateBuilderPipeline(stages: [first])
    }
    
    /// If the condition of an `if` statement is `false`, then this method will
    /// be called and the result of evaluating the expressions in the `false`
    /// block will be returned unmodified.
    /// - note: We do not need to preserve type information
    ///         from both the `true` and `false` blocks, so this function does
    ///         not wrap its passed value.
    public static func buildEither(second: AggregateBuilderStage) -> AggregateBuilderPipeline {
        return AggregateBuilderPipeline(stages: [second])
    }
}

public struct AggregateBuilderPipeline: QueryCursor {
    public typealias Element = Document
    fileprivate var collection: MongoCollection!
    fileprivate var writing = false
    
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
}

extension MongoCollection {
    public func buildAggregate(@AggregateBuilder build: () -> AggregateBuilderPipeline) -> AggregateBuilderPipeline {
        var pipeline = build()
        pipeline.collection = self
        return pipeline
    }
}

public func match(_ query: Document) -> AggregateBuilderStage {
    return AggregateBuilderStage(document: [
        "$match": query
    ])
}

public func skip(_ n: Int) -> AggregateBuilderStage {
    assert(n > 0)
    
    return AggregateBuilderStage(document: [
        "$skip": n
    ])
}

public func limit(_ n: Int) -> AggregateBuilderStage {
    assert(n > 0)
    
    return AggregateBuilderStage(document: [
        "$limit": n
    ])
}

public func sample(_ n: Int) -> AggregateBuilderStage {
    assert(n > 0)
    
    return AggregateBuilderStage(document: [
        "$sample": n
    ])
}

public func project(_ projection: Projection) -> AggregateBuilderStage {
    return AggregateBuilderStage(document: [
        "$project": projection.document
    ])
}

public func paginateRange(_ range: Range<Int>) -> AggregateBuilderStage {
    return AggregateBuilderStage(documents: [
        ["$skip": range.lowerBound],
        ["$limit": range.count]
    ])
}


extension AggregateBuilderPipeline {
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
