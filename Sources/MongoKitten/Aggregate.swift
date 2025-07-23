import Tracing
import NIO
import MongoKittenCore
import MongoClient

/// An aggregation pipeline that processes documents through multiple stages.
///
/// The `AggregateBuilderPipeline` represents a sequence of stages that process
/// documents. Each stage transforms the documents in some way and passes the
/// results to the next stage.
///
/// ## Basic Usage
/// ```swift
/// let pipeline = collection.buildAggregate {
///     Match(where: "age" >= 18)
///     Group([
///         "_id": "$country",
///         "count": ["$sum": 1]
///     ])
/// }
///
/// // Execute and process results
/// for try await result in pipeline {
///     print(result)
/// }
/// ```
///
/// ## Pipeline Options
/// ```swift
/// let pipeline = collection.buildAggregate {
///     Match(where: "category" == "electronics")
///     Sort(by: "price", direction: .ascending)
/// }
/// .allowDiskUse() // For large datasets
/// .comment("Product analysis") // For logging
/// .collation(Collation(locale: "en")) // For string comparisons
/// .readConcern(.majority) // For consistency level
/// ```
///
/// ## Decoding Results
/// ```swift
/// struct ProductStats: Codable {
///     let category: String
///     let totalSales: Double
///     let averagePrice: Double
/// }
///
/// let stats = collection.buildAggregate {
///     Group([
///         "_id": "$category",
///         "totalSales": ["$sum": "$sales"],
///         "averagePrice": ["$avg": "$price"]
///     ])
/// }
///
/// for try await stat in stats.decode(ProductStats.self) {
///     print("\(stat.category): \(stat.totalSales)")
/// }
/// ```
///
/// ## Writing Results
/// ```swift
/// // Write results to another collection
/// try await pipeline.out(toCollection: "results")
/// ```
///
/// ## Performance Tips
/// - Use `allowDiskUse()` for large datasets that exceed memory limits
/// - Place filtering stages (`Match`) early in the pipeline
/// - Create indexes for fields used in `Sort`, `Match`, and `Group` stages
/// - Monitor the pipeline with `comment()` for easier debugging
public struct AggregateBuilderPipeline: CountableCursor {
    public typealias Element = Document

    /// The connection to use for this pipeline. If nil, the pipeline requests a connection from the pool
    internal var connection: MongoConnection?
    internal var collection: MongoCollection!
    internal var writing = false
    internal var _comment: String?
    internal var _allowDiskUse: Bool?
    internal var _collation: Collation?
    internal var _readConcern: ReadConcern?
    internal var _batchSize: Int32?
    
    /// Enables disk usage for large datasets that exceed memory limits.
    ///
    /// When processing large datasets, MongoDB may need to use disk space
    /// to store temporary data. This option allows that behavior.
    ///
    /// - Parameter allowDiskUse: Whether to allow disk usage (defaults to true)
    /// - Returns: The modified pipeline
    ///
    /// ## Example
    /// ```swift
    /// let pipeline = collection.buildAggregate {
    ///     Sort(by: "timestamp", direction: .ascending)
    /// }
    /// .allowDiskUse() // Allow using disk for large sorts
    /// ```
    public func allowDiskUse(_ allowDiskUse: Bool? = true) -> AggregateBuilderPipeline {
        var pipeline = self
        pipeline._allowDiskUse = allowDiskUse
        return pipeline
    }
    
    /// Adds a comment to this pipeline for logging and debugging.
    ///
    /// Comments appear in the server logs, profiler output, and
    /// explain plans, making it easier to track and debug pipelines.
    ///
    /// - Parameter comment: The comment to add
    /// - Returns: The modified pipeline
    ///
    /// ## Example
    /// ```swift
    /// let pipeline = collection.buildAggregate {
    ///     Match(where: "status" == "active")
    /// }
    /// .comment("Active user analysis")
    /// ```
    public func comment(_ comment: String?) -> AggregateBuilderPipeline {
        var pipeline = self
        pipeline._comment = comment
        return pipeline
    }
    
    /// Sets the collation for string comparisons in this pipeline.
    ///
    /// Collation allows you to specify language-specific rules for
    /// string comparison, such as rules for lettercase and accent marks.
    ///
    /// - Parameter collation: The collation rules to use
    /// - Returns: The modified pipeline
    ///
    /// ## Example
    /// ```swift
    /// let pipeline = collection.buildAggregate {
    ///     Sort(by: "name", direction: .ascending)
    /// }
    /// .collation(Collation(
    ///     locale: "en",
    ///     strength: .secondary
    /// ))
    /// ```
    public func collation(_ collation: Collation?) -> AggregateBuilderPipeline {
        var pipeline = self
        pipeline._collation = collation
        return pipeline
    }
    
    /// Sets the read concern level for this pipeline.
    ///
    /// Read concern determines the consistency and isolation properties
    /// of the data read by this pipeline.
    ///
    /// - Parameter readConcern: The read concern level
    /// - Returns: The modified pipeline
    ///
    /// ## Example
    /// ```swift
    /// let pipeline = collection.buildAggregate {
    ///     Match(where: "status" == "active")
    /// }
    /// .readConcern(.majority) // Ensure consistent reads
    /// ```
    public func readConcern(_ readConcern: ReadConcern?) -> AggregateBuilderPipeline {
        var pipeline = self
        pipeline._readConcern = readConcern
        return pipeline
    }

    /// Sets the batch size for cursor operations
    public func batchSize(_ batchSize: Int) -> AggregateBuilderPipeline {
        precondition(batchSize > 0, "Batch size must be positive")
        var pipeline = self
        pipeline._batchSize = Int32(batchSize)
        return pipeline
    }
    
    internal func makeCommand() -> AggregateCommand {
        var documents = [Document]()
        documents.reserveCapacity(stages.count * 2)
        
        for stage in stages {
            documents.append(stage.stage)
        }
        
        var command = AggregateCommand(
            inCollection: collection.name,
            pipeline: documents
        )
        
        command.comment = _comment
        command.allowDiskUse = _allowDiskUse
        command.collation = _collation
        command.readConcern = _readConcern
        if let batchSize = _batchSize {
            command.cursor.batchSize = batchSize
        }
        
        return command
    }
    
    /// Gets the connection to use for this pipeline
    public func getConnection() async throws -> MongoConnection {
        if let connection = connection {
            return connection
        }
        
        return try await collection.pool.next(for: .writable)
    }
    
    /// Executes the pipeline and returns a cursor
    @Sendable public func execute() async throws -> FinalizedCursor<AggregateBuilderPipeline> {
        let command = makeCommand()
        let connection = try await getConnection()
        
        #if DEBUG
        let minimalVersionRequired = stages.compactMap(\.minimalVersionRequired).max()
        
        if let actualVersion = await connection.wireVersion, let minimalVersion = minimalVersionRequired, actualVersion < minimalVersion {
            connection.logger.debug(
                "Aggregation might fail since one or more aggregation stages require a higher MongoDB version than provided by the current connection.",
                metadata: collection.database.logMetadata
            )
        }
        #endif

        let aggregateSpan: any Span
        if let context = collection.context {
            aggregateSpan = InstrumentationSystem.tracer.startAnySpan("Aggregate<\(collection.namespace)>", context: context)
        } else {
            aggregateSpan = InstrumentationSystem.tracer.startAnySpan("Aggregate<\(collection.namespace)>")
        }

        let cursorReply = try await connection.executeCodable(
            command,
            decodeAs: CursorReply.self,
            namespace: self.collection.database.commandNamespace,
            in: self.collection.transaction,
            sessionId: self.collection.sessionId ?? connection.implicitSessionId,
            logMetadata: self.collection.database.logMetadata,
            traceLabel: "Aggregate<\(self.collection.namespace)>",
            serviceContext: aggregateSpan.context
        )
        
        let cursor = MongoCursor(
            reply: cursorReply.cursor,
            in: self.collection.namespace,
            connection: connection,
            session: self.collection.session ?? connection.implicitSession,
            transaction: self.collection.transaction,
            traceLabel: "Aggregate<\(self.collection.namespace)>",
            context: aggregateSpan.context
        )
        
        return FinalizedCursor(basedOn: self, cursor: cursor)
    }
    
    public func transformElement(_ element: Document) throws -> Document {
        return element
    }
    
    /// The stages of this pipeline
    var stages: [AggregateBuilderStage]
    
    internal init(stages: [AggregateBuilderStage]) {
        self.stages = stages
    }
    
    /// Creates a new pipeline for the given collection and stages
    public init(
        stages: [AggregateBuilderStage],
        collection: MongoCollection
    ) {
        self.stages = stages
        self.collection = collection
    }
    
    /// Counts the number of documents in this pipeline.
    ///
    /// This method adds a `$count` stage to the end of the pipeline
    /// and returns the count of documents that reach that stage.
    ///
    /// - Returns: The number of documents in the pipeline result
    ///
    /// ## Example
    /// ```swift
    /// // Count active users by country
    /// let count = try await collection.buildAggregate {
    ///     Match(where: "status" == "active")
    ///     Group(["_id": "$country"])
    /// }.count()
    /// ```
    public func count() async throws -> Int {
        struct PipelineResultCount: Decodable {
            let count: Int
        }
        
        var pipeline = self
        pipeline.stages.append(Count(to: "count"))
        pipeline.stages.append(Project("count"))
        return try await pipeline.decode(PipelineResultCount.self).firstResult()?.count ?? 0
    }
    
    /// Writes the pipeline results to a collection.
    ///
    /// This method adds an `$out` stage to the end of the pipeline
    /// and executes it, writing all results to the specified collection.
    ///
    /// - Parameter collectionName: The name of the collection to write to
    ///
    /// ## Example
    /// ```swift
    /// // Process and save results
    /// try await collection.buildAggregate {
    ///     Match(where: "status" == "completed")
    ///     Group([
    ///         "_id": "$category",
    ///         "total": ["$sum": "$amount"]
    ///     ])
    /// }.out(toCollection: "categoryTotals")
    /// ```
    ///
    /// - Note: The target collection will be created if it doesn't exist,
    ///         and its contents will be completely replaced.
    public func out(toCollection collectionName: String) async throws {
        var pipeline = self
        pipeline.stages.append(Out(toCollection: collectionName))
        pipeline.writing = true
        
        _ = try await pipeline.execute()
    }
}
