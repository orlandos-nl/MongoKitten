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
    public static func buildBlock(_ content: AggregateBuilderStage) -> AggregateBuilderStage {
        return AggregateBuilderStage(documents: content.stages)
    }
    
    /// If there are multiple children, return them all as a MultiNode.
    public static func buildBlock(_ content: AggregateBuilderStage...) -> AggregateBuilderStage {
        return AggregateBuilderStage(documents: content.reduce([], { $0 + $1.stages }))
    }
    
    /// If the provided child is `nil`, build an empty MultiNode. Otherwise,
    /// return the wrapped value.
    public static func buildIf(_ content: AggregateBuilderStage?) -> AggregateBuilderStage {
        if let content = content {
            return AggregateBuilderStage(documents: content.stages)
        }
        
        return AggregateBuilderStage(documents: [])
    }
    
    /// If the condition of an `if` statement is `true`, then this method will
    /// be called and the result of evaluating the expressions in the `true` block
    /// will be returned unmodified.
    /// - note: We do not need to preserve type information
    ///         from both the `true` and `false` blocks, so this function does
    ///         not wrap its passed value.
    public static func buildEither(first: AggregateBuilderStage) -> AggregateBuilderStage {
        return AggregateBuilderStage(documents: first.stages)
    }
    
    /// If the condition of an `if` statement is `false`, then this method will
    /// be called and the result of evaluating the expressions in the `false`
    /// block will be returned unmodified.
    /// - note: We do not need to preserve type information
    ///         from both the `true` and `false` blocks, so this function does
    ///         not wrap its passed value.
    public static func buildEither(second: AggregateBuilderStage) -> AggregateBuilderStage {
        return AggregateBuilderStage(documents: second.stages)
    }
}

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
    public func buildAggregate(@AggregateBuilder build: () -> AggregateBuilderStage) -> AggregateBuilderPipeline {
        var pipeline = AggregateBuilderPipeline(stages: [build()])
        pipeline.collection = self
        return pipeline
    }
}

public func match(_ query: Document) -> AggregateBuilderStage {
    return .match(query)
}

public func match<Q: MongoKittenQuery>(_ query: Q) -> AggregateBuilderStage {
    return .match(query.makeDocument())
}

public func addFields(_ query: Document) -> AggregateBuilderStage {
    return .addFields(query)
}

public func skip(_ n: Int) -> AggregateBuilderStage {
    return .skip(n)
}

/// The `limit` aggregation limits the number of resulting documents to the given number
///
/// # MongoDB-Documentation:
/// [Link to the MongoDB-Documentation](https://docs.mongodb.com/manual/reference/operator/aggregation/limit/)
///
/// # Example:
/// ```
/// let pipeline = myCollection.aggregate([
///     .match("myCondition" == true),
///     .limit(5)
/// ])
///
/// pipeline.execute().whenComplete { result in
///    // ...
/// }
/// ```
///
/// - Parameter n: the maximum number of documents
/// - Returns: an `AggregateBuilderStage`
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

/// The `lookup` aggregation performs a join from another collection in the same database. This aggregation will add a new array to
/// your document including the matching documents.
///
/// # MongoDB-Documentation:
/// [Link to the MongoDB-Documentation](https://docs.mongodb.com/manual/reference/operator/aggregation/lookup/)
///
/// # Example:
/// There are two collections, named `users` and `userCategories`. In the `users` collection there is a reference to the _id
/// of the `userCategories`, because every user belongs to a category.
///
/// If you now want to aggregate all users and the corresponding user category, you can use the `$lookup` like this:
///
/// ```
/// let pipeline = userCollection.aggregate([
///     .lookup(from: "userCategories", "localField": "categoryID", "foreignField": "_id", newName: "userCategory")
/// ])
///
/// pipeline.execute().whenComplete { result in
///    // ...
/// }
/// ```
///
/// # Hint:
/// Because the matched documents will be inserted as an array no matter if there is only one item or more, you may want to unwind the joined documents:
///
/// ```
/// let pipeline = myCollection.aggregate([
///     .lookup(from: ..., newName: "newName"),
///     .unwind(fieldPath: "$newName")
/// ])
/// ```
///
/// - Parameters:
///   - from: the foreign collection, where the documents will be looked up
///   - localField: the name of the field in the input collection that shall match the `foreignField` in the `from` collection
///   - foreignField: the name of the field in the `fromCollection` that shall match the `localField` in the input collection
///   - newName: the collecting matches will be inserted as an array to the input collection, named as `newName`
/// - Returns: an `AggregateBuilderStage`
public func lookup(
    from: String,
    localField: String,
    foreignField: String,
    as newName: String
) -> AggregateBuilderStage {
    return .lookup(
        from: from,
        localField: localField,
        foreignField: foreignField,
        as: newName
    )
}

/// The `unwind` aggregation will deconstruct a field, that contains an array. It will return as many documents as are included
/// in the array and every output includes the original document with each item of the array
///
/// # MongoDB-Documentation:
/// [Link to the MongoDB-Documentation](https://docs.mongodb.com/manual/reference/operator/aggregation/unwind/)
///
/// # Example:
/// The original document:
///
/// ```
/// { "_id": 1, "boolItem": true, "arrayItem": ["a", "b", "c"] }
/// ```
///
/// The command in Swift:
///
/// ```
/// let pipeline = collection.aggregate([
///     .match("_id" == 1),
///     .unwind(fieldPath: "$arrayItem")
/// ])
/// ```
///
/// This will return three documents:
/// ```
/// { "_id": 1, "boolItem": true, "arrayItem": "a" }
/// { "_id": 1, "boolItem": true, "arrayItem": "b" }
/// { "_id": 1, "boolItem": true, "arrayItem": "c" }
/// ```
/// - Parameters:
///   - fieldPath: the field path to an array field. You have to prefix the path with "$"
///   - includeArrayIndex: this parameter is optional. If given, the new documents will hold a new field with the name of `includeArrayIndex` and this field will contain the array index
///   - preserveNullAndEmptyArrays: this parameter is optional. If it is set to `true`, the aggregation will also include the documents, that don't have an array that can be unwinded. default is `false`, so the `unwind` aggregation will remove all documents, where there is no value or an empty array at `fieldPath`
/// - Returns: an `AggregateBuilderStage`
public func unwind(
    fieldPath: String,
    includeArrayIndex: String? = nil,
    preserveNullAndEmptyArrays: Bool? = nil
) -> AggregateBuilderStage {
    return .unwind(
        fieldPath: fieldPath,
        includeArrayIndex: includeArrayIndex,
        preserveNullAndEmptyArrays: preserveNullAndEmptyArrays
    )
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
