import BSON
import NIO

/// Performs aggregation operation using the aggregation pipeline. The pipeline allows users to process data from a collection or other source with a sequence of stage-based manipulations.
public struct AggregateCommand: ReadCommand {
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
    
    public var readConcern: ReadConcern?
    
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
        self.aggregate = collection.namespace
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
    var operation: AggregateCommand
    
    init(on collection: Collection, transformer: @escaping (Document) -> Element) {
        self.collection = collection
        self.transformer = transformer
        self.operation = AggregateCommand(pipeline: [], in: collection)
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
    
    /// Groups documents by some specified expression and outputs to the next stage a document for each distinct grouping. The output documents contain an _id field which contains the distinct group by key. The output documents can also contain computed fields that hold the values of some accumulator expression grouped by the $group’s _id field. $group does not order its output documents.
    ///
    /// - parameter id: The distinct group by key. You can specify an _id value of `nil` to calculate accumulated values for all the input documents as a whole.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/group/index.html
    @discardableResult public func group(id: Primitive?, fields: [String: GroupAccumulator] = [:]) -> AggregateCursor<Element> {
        var document: Document = ["_id": id ?? Null()]
        
        for (field, accumulator) in fields {
            document[field] = accumulator.document
        }
        
        append(["$group": document])
        return self
    }
    
    /// Deconstructs an array field from the input documents to output a document for each element. Each output document is the input document with the value of the array field replaced by the element.
    ///
    /// - parameter path: Field path to an array field. To specify a field path, prefix the field name with a dollar sign $ and enclose in quotes.
    /// - parameter includeArrayIndex: Optional. The name of a new field to hold the array index of the element. The name cannot start with a dollar sign $.
    /// - parameter preserveNullAndEmptyArrays: Optional. If true, if the path is null, missing, or an empty array, $unwind outputs the document. If false, $unwind does not output a document if the path is null, missing, or an empty array. The default value is false.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/unwind/index.html
    @discardableResult public func unwind(_ path: String, includeArrayIndex: String? = nil, preserveNullAndEmptyArrays: Bool? = nil) -> AggregateCursor<Element> {
        append(["$unwind": ["path": path, "includeArrayIndex": includeArrayIndex, "preserveNullAndEmptyArrays": preserveNullAndEmptyArrays] as Document])
        return self
    }
    
    /// Equality match
    ///
    /// Performs a left outer join to an unsharded collection in the same database to filter in documents from the “joined” collection for processing. To each input document, the $lookup stage adds a new array field whose elements are the matching documents from the “joined” collection. The $lookup stage passes these reshaped documents to the next stage.
    ///
    /// - parameter from: Specifies the collection in the same database to perform the join with. The from collection cannot be sharded.
    /// - parameter localField: Specifies the field from the documents input to the $lookup stage. $lookup performs an equality match on the localField to the foreignField from the documents of the from collection. If an input document does not contain the localField, the $lookup treats the field as having a value of null for matching purposes.
    /// - parameter foreignField: Specifies the field from the documents in the from collection. $lookup performs an equality match on the foreignField to the localField from the input documents. If a document in the from collection does not contain the foreignField, the $lookup treats the value as null for matching purposes.
    /// - parameter targetField: Specifies the name of the new array field to add to the input documents. The new array field contains the matching documents from the from collection. If the specified name already exists in the input document, the existing field is overwritten.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/lookup/index.html
    @discardableResult public func lookup(from: String, localField: String, foreignField: String, as targetName: String) -> AggregateCursor<Element> {
        append(["$lookup": ["from": from, "localField": localField, "foreignField": foreignField, "as": targetName]])
        return self
    }
    
    // TODO: https://docs.mongodb.com/manual/reference/operator/aggregation/lookup/index.html - Join Conditions and Uncorrelated Sub-queries
    
    /// Adds the specified pipeline stage
    ///
    /// - parameter stage: The pipeline stage to add, like `["$limit": 100]`
    @discardableResult public func append(_ stage: Document) -> AggregateCursor<Element> {
        operation.pipeline.append(stage)
        return self
    }
    
    public func execute() -> EventLoopFuture<FinalizedCursor<AggregateCursor<Element>>> {
        let transaction = collection.makeTransactionQueryOptions()
        
        return self.collection.session.execute(command: self.operation, transaction: transaction).mapToResult(for: collection).map { cursor in
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
        let cursor = AggregateCursor(on: self.collection)
        cursor.operation = self.operation
        
        return cursor
            .count(into: "count")
            .decode(CountResult.self)
            .getFirstResult()
            .flatMapThrowing { result in
                guard let result = result else {
                    return 0
                }
                
                return result.count
        }
    }
}

/// A group accumulator operator
public enum GroupAccumulator {
    /// Returns the average value of the numeric values. $avg ignores non-numeric values.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/avg/#grp._S_avg
    case average([Primitive])
    
    /// Returns the value that results from applying an expression to the first document in a group of documents that share the same group by key. Only meaningful when documents are in a defined order.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/first/#grp._S_first
    case first(Primitive)
    
    /// Returns the value that results from applying an expression to the last document in a group of documents that share the same group by a field. Only meaningful when documents are in a defined order.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/last/#grp._S_last
    case last(Primitive)
    
    /// Returns the maximum value. $max compares both value and type, using the specified BSON comparison order for values of different types.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/max/#grp._S_max
    case max(Primitive)
    
    /// Returns the minimum value. $min compares both value and type, using the specified BSON comparison order for values of different types.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/min/#grp._S_min
    case min(Primitive)
    
    /// Returns an array of all values that result from applying an expression to each document in a group of documents that share the same group by key.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/push/#grp._S_push
    case push(Primitive)
    
    /// Returns an array of all unique values that results from applying an expression to each document in a group of documents that share the same group by key. Order of the elements in the output array is unspecified.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/addToSet/#grp._S_addToSet
    case addToSet(Primitive)
    
    /// Calculates the population standard deviation of the input values. Use if the values encompass the entire population of data you want to represent and do not wish to generalize about a larger population. $stdDevPop ignores non-numeric values.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/stdDevPop/#grp._S_stdDevPop
    case populationStandardDeviation(Primitive)
    
    /// Calculates the sample standard deviation of the input values. Use if the values encompass a sample of a population of data from which to generalize about the population. $stdDevSamp ignores non-numeric values.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/stdDevSamp/#grp._S_stdDevSamp
    case sampleStandardDeviation(Primitive)
    
    /// Calculates and returns the sum of numeric values. $sum ignores non-numeric values.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/sum/#grp._S_sum
    case sum(Primitive)
    
    /// The document representation of the group accumulator, like `["$sum": ...]`
    var document: Document {
        switch self {
        case .average(let val):
            return ["$avg": Document(array: val)]
        case .first(let val):
            return ["$first": val]
        case .last(let val):
            return ["$last": val]
        case .max(let val):
            return ["$max": val]
        case .min(let val):
            return ["$min": val]
        case .push(let val):
            return ["$push": val]
        case .addToSet(let val):
            return ["$addToSet": val]
        case .populationStandardDeviation(let val):
            return ["$stdDevPop": val]
        case .sampleStandardDeviation(let val):
            return ["$stdDevSamp": val]
        case .sum(let val):
            return ["$sum": val]
        }
    }
}
