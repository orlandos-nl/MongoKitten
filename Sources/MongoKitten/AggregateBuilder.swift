import MongoClient
import NIO

#if swift(>=5.1)
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

extension MongoCollection {
    public func buildAggregate(@AggregateBuilder build: () -> AggregateBuilderPipeline) -> AggregateBuilderPipeline {
        var pipeline = build()
        pipeline.collection = self
        return pipeline
    }
}

public func match(_ query: Document) -> AggregateBuilderStage {
    return .match(query)
}

public func skip(_ n: Int) -> AggregateBuilderStage {
    return .skip(n)
}

public func limit(_ n: Int) -> AggregateBuilderStage {
    return .limit(n)
}

public func sample(_ n: Int) -> AggregateBuilderStage {
    return .sample(n)
}

public func project(_ projection: Projection) -> AggregateBuilderStage {
    return .project(projection)
}

public func project(_ fields: String...) -> AggregateBuilderStage {
    var projection = Projection()
    
    for field in fields {
        projection.include(field)
    }
    
    return .project(projection)
}

public func sort(_ sort: Sort) -> AggregateBuilderStage {
    return .sort(sort)
}

public func paginateRange(_ range: Range<Int>) -> AggregateBuilderStage {
    return AggregateBuilderStage(documents: [
        ["$skip": range.lowerBound],
        ["$limit": range.count]
    ])
}
#endif
