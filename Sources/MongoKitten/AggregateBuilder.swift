import MongoClient
import NIO

#if swift(>=5.4)
@resultBuilder
public struct AggregateBuilder {
    public static func buildBlock() -> AggregateBuilderPipeline {
        return AggregateBuilderPipeline(stages: [])
    }
    
    public static func buildBlock(_ content: AggregateBuilderStage) -> [AggregateBuilderStage] {
        return [content]
    }
    
    public static func buildBlock(_ content: AggregateBuilderStage...) -> [AggregateBuilderStage] {
        return content
    }
    
    public static func buildIf(_ content: AggregateBuilderStage?) -> [AggregateBuilderStage] {
        if let content = content {
            return [content]
        }
        
        return []
    }
    
    public static func buildEither(first: AggregateBuilderStage) -> AggregateBuilderStage {
        return first
    }
    
    public static func buildEither(second: AggregateBuilderStage) -> AggregateBuilderStage {
        return second
    }
}
#elseif swift(>=5.1)
@_functionBuilder
public struct AggregateBuilder {
    public static func buildBlock() -> AggregateBuilderPipeline {
        return AggregateBuilderPipeline(stages: [])
    }
    
    public static func buildBlock(_ content: AggregateBuilderStage) -> AggregateBuilderStage {
        return AggregateBuilderStage(documents: content.stages)
    }
    
    public static func buildBlock(_ content: AggregateBuilderStage...) -> AggregateBuilderStage {
        return AggregateBuilderStage(documents: content.reduce([], { $0 + $1.stages }))
    }
    
    public static func buildIf(_ content: AggregateBuilderStage?) -> AggregateBuilderStage {
        if let content = content {
            return AggregateBuilderStage(documents: content.stages)
        }
        
        return AggregateBuilderStage(documents: [])
    }
    
    public static func buildEither(first: AggregateBuilderStage) -> AggregateBuilderStage {
        return AggregateBuilderStage(documents: first.stages)
    }
    
    public static func buildEither(second: AggregateBuilderStage) -> AggregateBuilderStage {
        return AggregateBuilderStage(documents: second.stages)
    }
}
#endif

#if swift(>=5.1)
extension MongoCollection {
	/// The `aggregate` command will create an `AggregateBuilderPipeline` where data can be aggregated
	/// and be transformed in multiple `AggregateStage` operations
	///
	/// With Swift > 5.1 you can use the function builders instead of the `aggregate(_ stages: [AggregateBuilderStage]) -> AggregateBuilderPipeline` function.
	///
	/// # Example:
	/// ```
	/// let pipeline = collection.buildAggregate {
	///    match("name" == "Superman")
	///    lookup(from: "addresses", "localField": "_id", "foreignField": "superheroID", newName: "address")
	///    unwind(fieldPath: "$address")
	/// }
	///
	/// pipeline.decode(SomeDecodableType.self).forEach { yourStruct in
	///	    // do sth. with your struct
	///	}.whenFailure { error in
	///	    // do sth. with the error
	/// }
	/// ```
	///
	/// - Parameter build: the `AggregateBuilderStage` as function builders
	/// - Returns: an `AggregateBuilderPipeline` that should be executed to get results
    public func buildAggregate(@AggregateBuilder build: () -> [AggregateBuilderStage]) -> AggregateBuilderPipeline {
        var pipeline = AggregateBuilderPipeline(stages: build())
        pipeline.collection = self
        return pipeline
    }
    
    internal func _buildAggregate(on connection: MongoConnection, @AggregateBuilder build: () -> [AggregateBuilderStage]) -> AggregateBuilderPipeline {
        var pipeline = AggregateBuilderPipeline(stages: build())
        pipeline.connection = connection
        pipeline.collection = self
        return pipeline
    }
}
#endif
