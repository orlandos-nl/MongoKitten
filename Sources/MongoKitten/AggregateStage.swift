import MongoClient
import MongoCore
import MongoKittenCore
import Foundation

/// A stage in an aggregation pipeline
public protocol AggregateBuilderStage {
    /// The stage as a document to be sent to the server
    var stage: Document { get }

    /// The minimal version required for this stage to work
    var minimalVersionRequired: WireVersion? { get }
}

/// A $match stage in an aggregation pipeline, used to filter documents
/// - SeeAlso: https://docs.mongodb.com/manual/reference/operator/aggregation/match/
public struct Match: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = nil
    
    public init(where conditions: Document) {
        self.stage = ["$match": conditions]
    }
    
    public init(where conditions: MongoKittenQuery) {
        self.stage = ["$match": conditions.makeDocument()]
    }
}

/// An $addFields stage in an aggregation pipeline, used to add new fields to documents
/// - SeeAlso: https://docs.mongodb.com/manual/reference/operator/aggregation/addFields/
public struct AddFields: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = .mongo3_4
    
    public init(_ fields: Document) {
        self.stage = ["$addFields": fields]
    }
}

/// A $group stage in an aggregation pipeline, used to group documents
/// - SeeAlso: https://docs.mongodb.com/manual/reference/operator/aggregation/group/
public struct Project: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion?
    
    public init(projection: Projection) {
        self.stage = ["$project": projection.document]
        self.minimalVersionRequired = projection.minimalVersion
    }
    
    public init(_ fields: FieldPath...) {
        var document = Document()
        for field in fields {
            document[field.string] = Projection.ProjectionExpression.included.primitive
        }
        
        self.stage = ["$project": document]
    }
}

/// A $sort stage in an aggregation pipeline, used to sort documents
/// - SeeAlso: https://docs.mongodb.com/manual/reference/operator/aggregation/sort/
public struct Sort: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = nil
    
    public init(by field: FieldPath, direction: Sorting.Order) {
        self.stage = [
            "$sort": [
                field.string: direction.rawValue
            ] as Document
        ]
    }
    
    public init(_ sort: Sorting) {
        self.stage = [
            "$sort": sort.document
        ]
    }
}

/// A $count stage in an aggregation pipeline, used to count documents and add the count to a field
/// - SeeAlso: https://docs.mongodb.com/manual/reference/operator/aggregation/count/
public struct Count: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = .mongo3_4
    
    public init(to field: String) {
        self.stage = ["$count": field]
    }
}

/// A $skip stage in an aggregation pipeline, used to skip a number of documents
/// - SeeAlso: https://docs.mongodb.com/manual/reference/operator/aggregation/skip/
public struct Skip: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = nil
    
    public init(_ n: Int) {
        self.stage = ["$skip": n]
    }
}

/// An $out stage in an aggregation pipeline, used to write the results to a collection
/// - SeeAlso: https://docs.mongodb.com/manual/reference/operator/aggregation/out/
public struct Out: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = nil
    
    public init(toCollection collectionName: String, in database: String? = nil) {
        if let db = database {
            self.stage = ["$out": ["db": db, "coll": collectionName ]]
            self.minimalVersionRequired = .mongo4_4
        } else { self.stage = ["$out": collectionName] }
    }
}

/// A $replaceRoot stage in an aggregation pipeline, used to replace the root document with a new one
/// - SeeAlso: https://docs.mongodb.com/manual/reference/operator/aggregation/replaceRoot/
public struct ReplaceRoot: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = .mongo3_4
    
    public init(with path: FieldPath) {
        self.stage = [
            "$replaceRoot": [
                "newRoot": path.projection
            ]
        ]
    }
}


/// The `limit` aggregation limits the number of resulting documents to the given number
///
/// # MongoDB-Documentation:
/// [Link to the MongoDB-Documentation](https://docs.mongodb.com/manual/reference/operator/aggregation/limit/)
///
/// # Example:
/// ```swift
/// let pipeline = myCollection.aggregate([
///     Match("myCondition" == true),
///     Limit(5)
/// ])
/// ```
///
/// - Parameter n: the maximum number of documents
/// - Returns: An ``AggregateBuilderStage``
public struct Limit: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = nil
    
    public init(_ n: Int) {
        self.stage = ["$limit": n]
    }
}

/// The `sample` aggregation randomly selects the given number of documents
/// - SeeAlso: https://docs.mongodb.com/manual/reference/operator/aggregation/sample/
public struct Sample: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = .mongo3_2
    
    public init(_ n: Int) {
        assert(n > 0)
        
        self.stage = ["$sample": ["size": n]]
    }
}

/// The `$lookup` aggregation performs a join from another collection in the same database. This aggregation will add a new array to
/// your document including the matching documents.
///
/// [The MongoDB-Documentation](https://docs.mongodb.com/manual/reference/operator/aggregation/lookup/)
///
/// **Example**
///
/// There are two collections, named `users` and `userCategories`. In the `users` collection there is a reference to the _id
/// of the `userCategories`, because every user belongs to a category.
///
/// If you now want to aggregate all users and the corresponding user category, you can use the `$lookup` like this:
///
/// ```swift
/// let pipeline = userCollection.aggregate([
///     Lookup(from: "userCategories", "localField": "categoryID", "foreignField": "_id", newName: "userCategory")
/// ])
/// ```
///
/// **Hint**
///
/// Because the matched documents will be inserted as an array no matter if there is only one item or more, you may want to unwind the joined documents:
///
/// ```swift
/// let pipeline = myCollection.aggregate([
///     Lookup(from: ..., newName: "newName"),
///     Unwind(fieldPath: "$newName")
/// ])
/// ```
///
/// - Parameters:
///   - from: the foreign collection, where the documents will be looked up
///   - localField: the name of the field in the input collection that shall match the `foreignField` in the `from` collection
///   - foreignField: the name of the field in the `fromCollection` that shall match the `localField` in the input collection
///   - newName: the collecting matches will be inserted as an array to the input collection, named as `newName`
/// - Returns: an ``AggregateBuilderStage``
public struct Lookup: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = nil
    
    public init(
        from: String,
        localField: FieldPath,
        foreignField: FieldPath,
        as newName: FieldPath
    ) {
        self.stage = [
            "$lookup":
                [
                    "from": from,
                    "localField": localField.string,
                    "foreignField": foreignField.string,
                    "as": newName.string
                ]
        ]
    }
    
    public init(
        from: String,
        localField: FieldPath,
        foreignField: FieldPath,
        using pipelineVariables: Document? = nil,
        @AggregateBuilder pipeline: () -> [AggregateBuilderStage],
        as newField: FieldPath
    ) {
        let pipelineStages = pipeline().map(\.stage)
                
        var command: Document = [
            "$lookup": [
                "from": from,
                "localField": localField.string,
                "foreignField": foreignField.string,
                "pipeline": pipelineStages,
                "as": newField.string
            ] as Document
        ]
        
        if let variables = pipelineVariables {
            command["$lookup"]["let"] = variables
        }
        
        self.stage = command
    }
}

/// The `$unwind` aggregation will deconpublic struct a field, that contains an array. It will return as many documents as are included
/// in the array and every output includes the original document with each item of the array
///
/// - [The MongoDB-Documentation](https://docs.mongodb.com/manual/reference/operator/aggregation/unwind/)
///
/// **Example**
///
/// The original document:
///
/// ```json
/// { "_id": 1, "boolItem": true, "arrayItem": ["a", "b", "c"] }
/// ```
///
/// The command in Swift:
///
/// ```swift
/// let pipeline = collection.aggregate([
///     Match("_id" == 1),
///     Unwind(fieldPath: "$arrayItem")
/// ])
/// ```
///
/// This will return three documents:
/// ```json
/// { "_id": 1, "boolItem": true, "arrayItem": "a" }
/// { "_id": 1, "boolItem": true, "arrayItem": "b" }
/// { "_id": 1, "boolItem": true, "arrayItem": "c" }
/// ```
///
/// - Parameters:
///   - fieldPath: the field path to an array field. You have to prefix the path with "$"
///   - includeArrayIndex: this parameter is optional. If given, the new documents will hold a new field with the name of `includeArrayIndex` and this field will contain the array index
///   - preserveNullAndEmptyArrays: this parameter is optional. If it is set to `true`, the aggregation will also include the documents, that don't have an array that can be unwinded. default is `false`, so the `$unwind` aggregation will remove all documents, where there is no value or an empty array at `fieldPath`
/// - Returns: an ``AggregateBuilderStage``
public struct Unwind: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = .mongo3_2
    
    public init(fieldPath: FieldPath, includeArrayIndex: String? = nil, preserveNullAndEmptyArrays: Bool? = nil) {
        var d = Document()
        d["path"] = fieldPath.projection
        
        
        if let incl = includeArrayIndex {
            d["includeArrayIndex"] = incl
            self.minimalVersionRequired = .mongo3_2
        }
        
        if let pres = preserveNullAndEmptyArrays {
            d["preserveNullAndEmptyArrays"] = pres
            self.minimalVersionRequired = .mongo3_2
        }
        
        self.stage = ["$unwind": d]
    }
}

/// The point for which to find the closest documents.
/// - Parameters:
///   - useLegacy: Wether or not to use the [legacy coordinate pair](https://docs.mongodb.com/manual/reference/glossary/#term-legacy-coordinate-pairs). `false` by default and uses a GeoJSON Point
///   - longitude: The longitude.
///   - latitude: The latitude.
///   - distanceField: The output field that contains the calculated distance. To specify a field within an embedded document, use [dot notation](https://docs.mongodb.com/manual/reference/glossary/#term-dot-notation) .
///   - spherical: Determines how MongoDB calculates the distance between two points: When true, MongoDB uses $nearSphere semantics and calculates distances using spherical geometry. When false, MongoDB uses $near semantics: spherical geometry for 2dsphere indexes and planar geometry for 2d indexes.
///   - maxDistance: The maximum distance from the center point that the documents can be. MongoDB limits the results to those documents that fall within the specified distance from the center point. Specify the distance in meters if the specified point is GeoJSON and in radians if the specified point is legacy coordinate pairs.
///   - query: Optional. Limits the results to the documents that match the query. The query syntax is the usual MongoDB read operation query syntax. You cannot specify a $near predicate in the query field of the $geoNear stage.
///   - distanceMultiplier: Optional. The factor to multiply all distances returned by the query. For example, use the distanceMultiplier to convert radians, as returned by a spherical query, to kilometers by multiplying by the radius of the Earth.
///   - includeLocs: Optional. This specifies the output field that identifies the location used to calculate the distance. This option is useful when a location field contains multiple locations. To specify a field within an embedded document, use dot notation.
///   - uniqueDocuments: Optional. If this value is true, the query returns a matching document once, even if more than one of the document’s location fields match the query.
///   - minDistance: Optional. The minimum distance from the center point that the documents can be. MongoDB limits the results to those documents that fall outside the specified distance from the center point.
///   - key: Specify the geospatial indexed field to use when calculating the distance. If your collection has multiple 2d and/or multiple 2dsphere indexes, you must use the key option to specify the indexed field path to use. Specify Which Geospatial Index to Use provides a full example. If there is more than one 2d index or more than one 2dsphere index and you do not specify a key, MongoDB will return an error. If you do not specify the key, and you have at most only one 2d index and/or only one 2dsphere index, MongoDB looks first for a 2d index to use. If a 2d index does not exists, then MongoDB looks for a 2dsphere index to use.
public struct GeoNear: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = nil
    
    public init(
        useLegacy: Bool = false,
        longitude: Double,
        latitude: Double,
        distanceField: String,
        spherical: Bool = false,
        maxDistance: Double? = nil,
        query: Document? = nil,
        distanceMultiplier: Double? = nil,
        includeLocs: String? = nil,
        uniqueDocuments: Bool? = nil,
        minDistance: Double? = nil,
        key: FieldPath? = nil
    ) {
        var geoNear: Document = ["distanceField": distanceField,
                                 "spherical": spherical]
        
        if useLegacy {
            geoNear["near"] = [longitude, latitude]
        } else {
            geoNear["near"] = ["type": "Point", "coordinates": [longitude, latitude]] as Document
        }
        
        geoNear["maxDistance"] = maxDistance
        
        geoNear["query"] = query
        
        geoNear["distanceMultiplier"] = distanceMultiplier
        
        geoNear["includeLocs"] = includeLocs
        
        geoNear["uniqueDocs"] = uniqueDocuments
        
        geoNear["minDistance"] = minDistance
        
        geoNear["key"] = key?.string
        
        self.stage = ["$geoNear": geoNear]
    }
}
