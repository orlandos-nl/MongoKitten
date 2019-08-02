import BSON


/// A Builder for nested pipelines.
private final class SubAggregateBuilder: AggregateBuilder {
    public var pipeline: [Document] = []
    
    @discardableResult public func append(_ stage: Document) -> Self {
        pipeline.append(stage)
        return self
    }

}

/// Type that conforms to AggregateBuilder can beneficiate for helper function to build an Aggregate pipeline
public protocol AggregateBuilder: class {

    /// Adds the specified pipeline stage
    ///
    /// - parameter stage: The pipeline stage to add, like `["$limit": 100]`
    @discardableResult func append(_ stage: Document) -> Self
}

public extension AggregateBuilder {
 
    /// Limits the number of documents passed to the next stage in the pipeline.
    ///
    /// - parameter limit: A positive integer that specifies the maximum number of documents to pass along.
    @discardableResult func limit(_ limit: Int) -> Self {
        append(["$limit": limit])
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
    @discardableResult func match(_ query: Query) -> Self {
        append(["$match": query.document])
        return self
    }

    /// Groups documents by some specified expression and outputs to the next stage a document for each distinct grouping. The output documents contain an _id field which contains the distinct group by key. The output documents can also contain computed fields that hold the values of some accumulator expression grouped by the $group’s _id field. $group does not order its output documents.
    ///
    /// - parameter id: The distinct group by key. You can specify an _id value of `nil` to calculate accumulated values for all the input documents as a whole.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/group/index.html
    @discardableResult func group(id: Primitive?, fields: [String: GroupAccumulator] = [:]) -> Self {
        var document: Document = ["_id": id ?? Null()]
        
        for (field, accumulator) in fields {
            document[field] = accumulator.document
        }
        
        append(["$group": document])
        return self
    }

    /// Skips over the specified number of documents that pass into the stage and passes the remaining documents to the next stage in the pipeline.
    ///
    /// - parameter skip: A positive integer that specifies the maximum number of documents to skip.
    @discardableResult func skip(_ skip: Int) -> Self {
        append(["$skip": skip])
        return self
    }
    
    /// Passes along the documents with the requested fields to the next stage in the pipeline. The specified fields can be existing fields from the input documents or newly computed fields.
    ///
    /// - parameter projection: A document that can specify the inclusion of fields, the suppression of the _id field, the addition of new fields, and the resetting of the values of existing fields. Alternatively, you may specify the exclusion of fields.
    @discardableResult func project(_ projection: Projection) -> Self {
        append(["$project": projection.document])
        return self
    }
    
    /// Sorts all input documents and returns them to the pipeline in sorted order.
    ///
    /// - parameter sort: A specification of the field(s) to sort and the respective sort order.
    @discardableResult func sort(_ sort: Sort) -> Self {
        append(["$sort": sort.document])
        return self
    }
    
    /// Returns a document that contains a count of the number of documents input to the stage.
    ///
    /// - parameter key: The name of the output field which has the count as its value. It must be a non-empty string, must not start with $ and must not contain the . character.
    @discardableResult func count(into key: String) -> Self {
        append(["$count": key])
        return self
    }

    
    /// Deconstructs an array field from the input documents to output a document for each element. Each output document is the input document with the value of the array field replaced by the element.
    ///
    /// - parameter path: Field path to an array field. To specify a field path, prefix the field name with a dollar sign $ and enclose in quotes.
    /// - parameter includeArrayIndex: Optional. The name of a new field to hold the array index of the element. The name cannot start with a dollar sign $.
    /// - parameter preserveNullAndEmptyArrays: Optional. If true, if the path is null, missing, or an empty array, $unwind outputs the document. If false, $unwind does not output a document if the path is null, missing, or an empty array. The default value is false.
    ///
    /// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/unwind/index.html
    @discardableResult func unwind(_ path: String, includeArrayIndex: String? = nil, preserveNullAndEmptyArrays: Bool? = nil) -> Self {
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
    @discardableResult func lookup(from: String, localField: String, foreignField: String, as targetName: String) -> Self {
        append(["$lookup": ["from": from, "localField": localField, "foreignField": foreignField, "as": targetName]])
        return self
    }
    
    /// Equality match
    ///
    /// Performs a left outer join to an unsharded collection in the same database to filter in documents from the “joined” collection for processing. To each input document, the $lookup stage adds a new array field whose elements are the matching documents from the “joined” collection. The $lookup stage passes these reshaped documents to the next stage.
    ///
    /// - parameter from: Specifies the collection in the same database to perform the join with. The from collection cannot be sharded.
    /// - parameter targetField: Specifies the name of the new array field to add to the input documents. The new array field contains the matching documents from the from collection. If the specified name already exists in the input document, the existing field is overwritten.
    /// - parameter localField: Optional. Specifies variables to use in the pipeline field stages. Use the variable expressions to access the fields from the documents input to the $lookup stage. The pipeline cannot directly access the input document fields. Instead, first define the variables for the input document fields, and then reference the variables in the stages in the pipeline. To access the let variables in the pipeline, use the $expr operator.
    /// - parameter foreignField: Specifies the pipeline to run on the joined collection. The pipeline determines the resulting documents from the joined collection. To return all documents, specify an empty pipeline []. The pipeline cannot directly access the input document fields. Instead, first define the variables for the input document fields, and then reference the variables in the stages in the pipeline. To access the let variables in the pipeline, use the $expr operator.
    ///
    // - see: https://docs.mongodb.com/manual/reference/operator/aggregation/lookup/index.html - Join Conditions and Uncorrelated Sub-queries
    @discardableResult func lookup(from: String, as targetName: String, `let`: Document, pipelineBuilder: (AggregateBuilder) -> ()) -> Self {
        let subAggregateBuilder = SubAggregateBuilder()
        pipelineBuilder(subAggregateBuilder)
        let lookupDocument: Document = [
            "from": from,
            "as": targetName,
            "let" : `let`,
            "pipeline": subAggregateBuilder.pipeline
        ]
        append(["$lookup": lookupDocument])
        return self
    }
}