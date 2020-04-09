import NIO
import MongoKittenCore
import MongoClient

extension MongoCollection {
	/// The `aggregate` command will create an `AggregateBuilderPipeline` where data can be aggregated
	/// and be transformed in multiple `AggregateStage` operations
	///
	/// # Hint:
	/// With Swift > 5.1 you can also use the function builders. See the documentation at `buildAggregate`
	///
	/// # Example:
	/// ```
	/// let pipeline = collection.aggregate([
	///     .match("name" == "Superman"),
	///     .unwind(fieldPath: "$arrayItem")
	/// ])
	///
	/// pipeline.decode(SomeDecodableType.self).forEach { yourStruct in
	///	    // do sth. with your struct
	///	}.whenFailure { error in
	///	    // do sth. with the error
	/// }
	/// ```
	///
	/// The same example with function builders:
	///
	/// ```
	/// let pipeline = collection.buildAggregate {
	///    match("name" == "Superman")
	///    unwind(fieldPath: "$arrayItem")
	/// }
	/// ```
	///
	/// - Parameter stages: an array of `AggregateBuilderStage`.
	/// - Returns: returns an `AggregateBuilderPipeline`
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
    
    public var eventLoop: EventLoop { collection.eventLoop }
    public var hoppedEventLoop: EventLoop? { collection.hoppedEventLoop }
    
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
                    hoppedEventLoop: self.hoppedEventLoop,
                    session: connection.implicitSession,
                    transaction: self.collection.transaction
                )
                return FinalizedCursor(basedOn: self, cursor: cursor)
            }
        }._mongoHop(to: hoppedEventLoop)
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
            return count?.count ?? 0
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
