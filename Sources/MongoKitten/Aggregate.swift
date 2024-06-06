import Tracing
import NIO
import MongoKittenCore
import MongoClient

/// An aggregation pipeline, used to query a collection
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
    
    public func allowDiskUse(_ allowDiskUse: Bool? = true) -> AggregateBuilderPipeline {
        var pipeline = self
        pipeline._allowDiskUse = allowDiskUse
        return pipeline
    }
    
    /// Adds a comment to this pipeline, which will be logged in the server logs
    public func comment(_ comment: String?) -> AggregateBuilderPipeline {
        var pipeline = self
        pipeline._comment = comment
        return pipeline
    }
    
    /// Sets the collation for this pipeline
    public func collation(_ collation: Collation?) -> AggregateBuilderPipeline {
        var pipeline = self
        pipeline._collation = collation
        return pipeline
    }
    
    /// Sets the read concern for this pipeline
    public func readConcern(_ readConcern: ReadConcern?) -> AggregateBuilderPipeline {
        var pipeline = self
        pipeline._readConcern = readConcern
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
    
    /// Counts the number of documents in this pipeline and returns the result
    public func count() async throws -> Int {
        struct PipelineResultCount: Decodable {
            let count: Int
        }
        
        var pipeline = self
        pipeline.stages.append(Count(to: "count"))
        pipeline.stages.append(Project("count"))
        return try await pipeline.decode(PipelineResultCount.self).firstResult()?.count ?? 0
    }
    
    /// Outputs the results of this pipeline to a collection with the given name
    public func out(toCollection collectionName: String) async throws {
        var pipeline = self
        pipeline.stages.append(Out(toCollection: collectionName))
        pipeline.writing = true
        
        _ = try await pipeline.execute()
    }
}
