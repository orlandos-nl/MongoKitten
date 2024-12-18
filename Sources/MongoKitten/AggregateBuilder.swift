import MongoClient
import NIO

/// A result builder for creating MongoDB aggregation pipelines in a type-safe and declarative way.
///
/// The `AggregateBuilder` provides a DSL-like syntax for creating aggregation pipelines
/// that can transform, filter, group, and analyze data in MongoDB collections.
///
/// ## Basic Usage
/// ```swift
/// let pipeline = collection.buildAggregate {
///     // Filter for adult users
///     Match(where: "age" >= 18)
///
///     // Group by country and calculate average age
///     Group([
///         "_id": "$country",
///         "avgAge": ["$avg": "$age"]
///     ])
///
///     // Sort by average age
///     Sort(by: "avgAge", direction: .descending)
/// }
///
/// // Execute and process results
/// for try await result in pipeline {
///     print(result)
/// }
/// ```
///
/// ## Common Stages
/// - `Match`: Filters documents (like a find query)
/// - `Group`: Groups documents by a key and can perform aggregations
/// - `Sort`: Sorts documents
/// - `Project`: Reshapes documents by including, excluding, or transforming fields
/// - `Lookup`: Performs a left outer join with another collection
/// - `Unwind`: Deconstructs an array field into multiple documents
///
/// ## Pipeline Options
/// The pipeline can be customized with additional options:
/// ```swift
/// let pipeline = collection.buildAggregate {
///     Match(where: "category" == "electronics")
///     Sort(by: "price", direction: .ascending)
/// }
/// .allowDiskUse() // For large datasets
/// .comment("Product analysis")
/// .collation(Collation(locale: "en"))
/// ```
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
	/// Creates an aggregation pipeline for complex data processing and analysis.
	///
	/// The aggregation framework allows you to analyze and transform documents
	/// as they pass through different stages. Each stage performs a specific
	/// operation on the input documents and passes the results to the next stage.
	///
	/// ## Example: User Statistics
	/// ```swift
	/// let stats = users.buildAggregate {
	///     // Filter active users
	///     Match(where: "status" == "active")
	///
	///     // Group by country and calculate stats
	///     Group([
	///         "_id": "$country",
	///         "totalUsers": ["$sum": 1],
	///         "avgAge": ["$avg": "$age"],
	///         "minAge": ["$min": "$age"],
	///         "maxAge": ["$max": "$age"]
	///     ])
	///
	///     // Sort by total users
	///     Sort(by: "totalUsers", direction: .descending)
	/// }
	///
	/// // Process results
	/// for try await countryStats in stats.decode(CountryStats.self) {
	///     print("\(countryStats.country): \(countryStats.totalUsers) users")
	/// }
	/// ```
	///
	/// ## Example: Complex Join
	/// ```swift
	/// let orderDetails = orders.buildAggregate {
	///     // Match recent orders
	///     Match(where: "orderDate" >= oneWeekAgo)
	///
	///     // Join with users collection
	///     Lookup(
	///         from: "users",
	///         localField: "userId",
	///         foreignField: "_id",
	///         newName: "user"
	///     )
	///
	///     // Unwind the user array (converts it to a single document)
	///     Unwind(fieldPath: "$user")
	///
	///     // Project only needed fields
	///     Project(projection: [
	///         "orderId": 1,
	///         "total": 1,
	///         "userName": "$user.name",
	///         "userEmail": "$user.email"
	///     ])
	/// }
	/// ```
	///
	/// ## Performance Considerations
	/// - Use `Match` stages early to reduce the number of documents processed
	/// - Consider using `allowDiskUse()` for large datasets
	/// - Index fields used in `Sort`, `Match`, and `Group` stages
	/// - Monitor the explain plan for pipeline optimization
	///
	/// - Parameter build: A closure that builds the pipeline stages
	/// - Returns: An executable aggregation pipeline
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
