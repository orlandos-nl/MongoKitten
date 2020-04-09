import MongoClient

public struct AggregateBuilderStage {
    internal var stages: [Document]
    
    public init(document: Document) {
        self.stages = [document]
    }
    
    internal init(documents: [Document]) {
        self.stages = documents
    }
    
    public static func match(_ query: Document) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$match": query
        ])
    }
	
	public static func match<Q: MongoKittenQuery>(_ query: Q) -> AggregateBuilderStage {
		return AggregateBuilderStage(document: [
			"$match": query.makeDocument()
		])
	}
    
    public static func addFields(_ query: Document) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$addFields": query
        ])
    }
    
    public static func sort(_ sort: Sort) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$sort": sort.document
        ])
    }
    
    public static func project(_ projection: Projection) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$project": projection.document
        ])
    }
    
    public static func project(_ fields: String...) -> AggregateBuilderStage {
        var document = Document()
        for field in fields {
            document[field] = Projection.ProjectionExpression.included.makePrimitive()
        }
        
        return AggregateBuilderStage(document: [
            "$project": document
        ])
    }
    
    public static func count(to field: String) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$count": field
        ])
    }
    
    public static func skip(_ n: Int) -> AggregateBuilderStage {
        assert(n > 0)
        
        return AggregateBuilderStage(document: [
            "$skip": n
        ])
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
	///    ...
	/// }
	/// ```
	///
	/// - Parameter n: the maximum number of documents
	/// - Returns: returns an `AggregateBuilderStage`
    public static func limit(_ n: Int) -> AggregateBuilderStage {
        assert(n > 0)
        
        return AggregateBuilderStage(document: [
            "$limit": n
        ])
    }
    
    public static func sample(_ n: Int) -> AggregateBuilderStage {
        assert(n > 0)
        
        return AggregateBuilderStage(document: [
            "$sample": n
        ])
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
	///    ...
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
	/// - Returns: returns an `AggregateBuilderStage`
    public static func lookup(
        from: String,
        localField: String,
        foreignField: String,
        as newName: String
    ) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$lookup": [
                "from": from,
                "localField": localField,
                "foreignField": foreignField,
                "as": newName
            ]
        ])
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
	/// - Returns: returns an `AggregateBuilderStage`
    public static func unwind(
        fieldPath: String,
        includeArrayIndex: String? = nil,
        preserveNullAndEmptyArrays: Bool? = nil
    ) -> AggregateBuilderStage {
        var d = Document()
        d["path"] = fieldPath
        
        if let incl = includeArrayIndex {
            d["includeArrayIndex"] = incl
        }
        
        if let pres = preserveNullAndEmptyArrays {
            d["preserveNullAndEmptyArrays"] = pres
        }
        
        return AggregateBuilderStage(document: ["$unwind": d])
    }
}
