import MongoClient
import NIO

/// A result builder for the ``MongoCollection/buildAggregate(build:)`` command which allows you to create an `AggregateBuilderPipeline` with a fluent syntax
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

extension MongoCollection {
	/// The `aggregate` command will create an ``AggregateBuilderPipeline`` where data can be aggregated
	/// and be transformed in multiple ``AggregateBuilderStage`` operations
	///
	/// # Example:
	/// ```swift
    /// let superheroes: MongoCollection = ...
	/// let pipeline = collection.buildAggregate {
	///    Match(where: "name" == "Superman")
	///    Lookup(from: "addresses", "localField": "_id", "foreignField": "superheroID", newName: "address")
	///    Unwind(fieldPath: "$address")
	/// }
	///
	/// for try await result in pipeline.decode(SomeDecodableType.self) {
    ///   print(result)
	/// }
	/// ```
	///
	/// - Parameter build: the ``AggregateBuilderStage`` as function builders
	/// - Returns: an `AggregateBuilderPipeline` that should be executed to get results
    public func buildAggregate(@AggregateBuilder build: () -> [AggregateBuilderStage]) -> AggregateBuilderPipeline {
        return AggregateBuilderPipeline(
            stages: build(),
            collection: self
        )
    }
    
    internal func _buildAggregate(on connection: MongoConnection, @AggregateBuilder build: () -> [AggregateBuilderStage]) -> AggregateBuilderPipeline {
        var pipeline = AggregateBuilderPipeline(stages: build())
        pipeline.connection = connection
        pipeline.collection = self
        return pipeline
    }
}
