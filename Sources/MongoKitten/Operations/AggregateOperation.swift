import BSON
import NIO

/// Performs aggregation operation using the aggregation pipeline. The pipeline allows users to process data from a collection or other source with a sequence of stage-based manipulations.
public struct AggregateOperation: MongoDBCommand {
    typealias Reply = CursorReply
    
    internal var namespace: Namespace {
        return aggregate
    }
    
    /// The name of the collection or view that acts as the input for the aggregation pipeline.
    internal let aggregate: Namespace
    
    /// An array of aggregation pipeline stages that process and transform the document stream as part of the aggregation pipeline.
    public var pipeline: [Document]
    
    /// Optional. Specifies to return the information on the processing of the pipeline.
    public var explain: Bool?
    
    /// Optional. Enables writing to temporary files. When set to `true`, aggregation stages can write data to the `_tmp` subdirectory in the `dbPath` directory.
    public var allowDiskUse: Bool?
    
    /// Specify a document that contains options that control the creation of the cursor object.
    ///
    /// Changed in version 3.6: MongoDB 3.6 removes the use of aggregate command without the cursor option unless the command includes the explain option. Unless you include the explain option, you must specify the cursor option.
    ///
    /// To indicate a cursor with the default batch size, specify cursor: `{}`.
    ///
    /// To indicate a cursor with a non-default batch size, use cursor: `{ batchSize: <num> }`.
    public var cursor = CursorSettings()
    
    /// Optional. Available only if you specify the `$out` aggregation operator.
    ///
    /// Enables aggregate to bypass document validation during the operation. This lets you insert documents that do not meet the validation requirements.
    ///
    /// New in version 3.2.
    public var bypassDocumentValidation: Bool?
    
    // readConcern
    // collation
    // hint
    
    /// Optional. Users can specify an arbitrary string to help trace the operation through the database profiler, currentOp, and logs.
    ///
    /// New in version 3.6.
    public var comment: String?
    
    // writeConcern
    
    static let writing = false
    static let emitsCursor = true
    
    public init(pipeline: [Document], in collection: Collection) {
        self.aggregate = collection.reference
        self.pipeline = pipeline
    }
}

fileprivate struct CountResult: Decodable {
    var count: Int
}

/// A cursor that is used for executing aggregates.
///
/// - see: `Collection.aggregate(...)`
public final class AggregateCursor<Element>: QueryCursor {
    public var collection: Collection
    private var transformer: (Document) -> Element
    public var batchSize: Int { return self.operation.cursor.batchSize ?? 101 }
    var operation: AggregateOperation
    
    init(on collection: Collection, transformer: @escaping (Document) -> Element) {
        self.collection = collection
        self.transformer = transformer
        self.operation = AggregateOperation(pipeline: [], in: collection)
    }
    
    @discardableResult public func setBatchSize(_ batchSize: Int) -> AggregateCursor<Element> {
        operation.cursor.batchSize = batchSize
        return self
    }
    
    /// Limits the number of documents passed to the next stage in the pipeline.
    ///
    /// - parameter limit: A positive integer that specifies the maximum number of documents to pass along.
    @discardableResult public func limit(_ limit: Int) -> AggregateCursor<Element> {
        operation.pipeline.append(["$limit": limit])
        return self
    }
    
    /// Skips over the specified number of documents that pass into the stage and passes the remaining documents to the next stage in the pipeline.
    ///
    /// - parameter skip: A positive integer that specifies the maximum number of documents to skip.
    @discardableResult public func skip(_ skip: Int) -> AggregateCursor<Element> {
        append(["$skip": skip])
        return self
    }
    
    /// Passes along the documents with the requested fields to the next stage in the pipeline. The specified fields can be existing fields from the input documents or newly computed fields.
    ///
    /// - parameter projection: A document that can specify the inclusion of fields, the suppression of the _id field, the addition of new fields, and the resetting of the values of existing fields. Alternatively, you may specify the exclusion of fields.
    @discardableResult public func project(_ projection: Projection) -> AggregateCursor<Element> {
        append(["$project": projection.document])
        return self
    }
    
    /// Sorts all input documents and returns them to the pipeline in sorted order.
    ///
    /// - parameter sort: A specification of the field(s) to sort and the respective sort order.
    @discardableResult public func sort(_ sort: Sort) -> AggregateCursor<Element> {
        append(["$sort": sort.document])
        return self
    }
    
    /// Returns a document that contains a count of the number of documents input to the stage.
    ///
    /// - parameter key: The name of the output field which has the count as its value. It must be a non-empty string, must not start with $ and must not contain the . character.
    @discardableResult public func count(into key: String) -> AggregateCursor<Element> {
        append(["$count": key])
        return self
    }
    
    /// Filters the documents to pass only the documents that match the specified condition(s) to the next pipeline stage.
    ///
    /// - parameter query: The query conditions
    ///
    /// ## Behavior
    ///
    /// ### Pipeline Optimization
    ///
    /// Place the $match as early in the aggregation pipeline as possible. Because $match limits the total number of documents in the aggregation pipeline, earlier $match operations minimize the amount of processing down the pipe.
    ///
    /// If you place a $match at the very beginning of a pipeline, the query can take advantage of indexes like any other db.collection.find() or db.collection.findOne().
    ///
    /// ## Restrictions
    ///
    /// You cannot use $where in $match queries as part of the aggregation pipeline.
    /// To use $text in the $match stage, the $match stage has to be the first stage of the pipeline.
    /// Views do not support text search.
    @discardableResult public func match(_ query: Query) -> AggregateCursor<Element> {
        append(["$match": query.document])
        return self
    }
    
    /// Adds the specified pipeline stage
    ///
    /// - parameter stage: The pipeline stage to add, like `["$limit": 100]`
    @discardableResult public func append(_ stage: Document) -> AggregateCursor<Element> {
        operation.pipeline.append(stage)
        return self
    }
    
    public func execute() -> EventLoopFuture<FinalizedCursor<AggregateCursor<Element>>> {
        return self.collection.connection.execute(command: self.operation).mapToResult(for: collection).map { cursor in
            return FinalizedCursor(basedOn: self, cursor: cursor)
        }
    }
    
    public func transformElement(_ element: Document) throws -> Element {
        return transformer(element)
    }
}

extension AggregateCursor where Element == Document {
    convenience init(on collection: Collection) {
        self.init(on: collection, transformer: { $0 })
    }
    
    /// Appends a `$count` stage to the aggregate, executes it, and returns the result
    public func count() -> EventLoopFuture<Int> {
        // TODO: Clone the cursor so this does not mutate the cursor
        return self
            .count(into: "count")
            .decode(CountResult.self)
            .getFirstResult()
            .thenThrowing { result in
                guard let result = result else {
                    throw MongoKittenError(.unexpectedNil, reason: .noResultDocument)
                }
                
                return result.count
        }
    }
}

