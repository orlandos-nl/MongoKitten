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
    
    public var maxTimeMS: Int?
    
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
public final class AggregateCursor<Element>: QueryCursor, AggregateBuilder {
    
    public var collection: Collection
    private var transformer: (Document) -> Element
    internal var maxTimeMS: Int? {
        get {
            return self.operation.maxTimeMS
        }
        set {
            self.operation.maxTimeMS = newValue
        }
    }
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
    
    @discardableResult public func allowDiskUse(_ allowDiskUse: Bool?) -> AggregateCursor<Element> {
        operation.allowDiskUse = allowDiskUse
        return self
    }
    
    @discardableResult public func append(_ stage: Document) -> Self {
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
            .thenThrowing { result in
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
