//
//  Query.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 15-03-16.
//  Copyright © 2016 OpenKitten. All rights reserved.
//

import Foundation
import BSON

#if os(macOS)
    typealias RegularExpression = NSRegularExpression
#endif


// MARK: Equations

/// Equals
public func ==(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .valEquals(key: key, val: pred))
}

/// MongoDB: `$ne`
public func !=(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .valNotEquals(key: key, val: pred))
}

// MARK: Comparisons

/// MongoDB: `$gt`. Used like native swift `>`
///
/// Checks whether the `Value` in `key` is larger than the `Value` provided
///
/// - returns: A new `Query` requiring the `Value` in the `key` to be larger than the provided `Value`
public func >(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .greaterThan(key: key, val: pred))
}

/// MongoDB: `$gte`. Used like native swift `>=`
///
/// Checks whether the `Value` in `key` is larger than or equal to the `Value` provided
///
/// - returns: A new `Query` requiring the `Value` in the `key` to be larger than or equal to the provided `Value`
public func >=(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .greaterThanOrEqual(key: key, val: pred))
}

/// MongoDB: `$lt`. Used like native swift `<`
///
/// Checks whether the `Value` in `key` is smaller than the `Value` provided
///
/// - returns: A new `Query` requiring the `Value` in the `key` to be smaller than the provided `Value`
public func <(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .smallerThan(key: key, val: pred))
}

/// MongoDB: `$lte`. Used like native swift `<=`
///
/// Checks whether the `Value` in `key` is smaller than or equal to the `Value` provided
///
/// - returns: A new `Query` requiring the `Value` in the `key` to be smaller than or equal to the provided `Value`
public func <=(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .smallerThanOrEqual(key: key, val: pred))
}

/// MongoDB `$and`. Used like native swift `&&`
///
/// Checks whether both these `Query` statements are true
///
/// - returns: A new `Query` that requires both the provided queries to be true
public func &&(lhs: Query, rhs: Query) -> Query {
    let lhs = lhs.aqt
    let rhs = rhs.aqt
    
    if case .and(var  a) = lhs, case .and(let b) = rhs {
        a.append(contentsOf: b)
        return Query(aqt: .and(a))
    } else if case .and(var a) = lhs {
        a.append(rhs)
        return Query(aqt: .and(a))
    } else if case .and(var b) = rhs {
        b.append(lhs)
        return Query(aqt: .and(b))
    } else {
        return Query(aqt: .and([lhs, rhs]))
    }
}

/// MongoDB: `$or`. Used like native swift `||`
///
/// Checks wither either of these `Query` statements is true
///
/// - returns: A new `Query` that is true when at least one of the two queries is true
public func ||(lhs: Query, rhs: Query) -> Query {
    let lhs = lhs.aqt
    let rhs = rhs.aqt
    
    if case .or(var  a) = lhs, case .or(let b) = rhs {
        a.append(contentsOf: b)
        return Query(aqt: .or(a))
    } else if case .or(var a) = lhs {
        a.append(rhs)
        return Query(aqt: .or(a))
    } else if case .or(var b) = rhs {
        b.append(lhs)
        return Query(aqt: .or(b))
    } else {
        return Query(aqt: .or([lhs, rhs]))
    }
}

/// Whether the `Query` provided is false
///
/// - parameter query: The query to be checked as false
///
/// - returns: A new `Query` that will be inverting the provided `Query`
public prefix func !(query: Query) -> Query {
    return Query(aqt: .not(query.aqt))
}

public func &=(lhs: Query, rhs: Query) -> Document {
    var lhs = lhs.queryDocument
    
    for (key, value) in rhs.queryDocument {
        lhs[key] = value
    }
    
    return lhs
}

/// Abstract Query Tree.
///
/// Made to be easily readable/usable so that an `AQT` instance can be easily translated to a `Document` as a Query or even possibly `SQL` in the future.
public indirect enum AQT {
    /// The types we support as raw `Int32` values
    ///
    /// The raw values are defined in https://docs.mongodb.com/manual/reference/operator/query/type/#op._S_type
    public enum AQTType: Int32 {
        case precisely
        
        /// Any number. So a `.double`, `.int32` or `.int64`
        case number = -2
        
        /// A double
        case double = 1
        
        /// A string
        case string = 2
        
        /// A `Document` I.E. "ordered" `Dictionary`
        case document = 3
        
        /// A `Document` as Array
        case array = 4
        
        /// Binary data
        case binary = 5
        
        // 6 is the deprecated type `undefined`
        
        /// A 12-byte unique `ObjectId`
        case objectId = 7
        
        /// A booelan
        case boolean = 8
        
        /// NSDate represented as UNIX Epoch time
        case dateTime = 9
        
        /// Null
        case null = 10
        
        /// A regex with options
        case regex = 11
        
        // 12 is an unsupported DBPointer
        
        /// JavaScript Code
        case jsCode = 13
        
        // 14 is an unsupported `Symbol`
        
        /// JavaScript code executed within a scope
        case jsCodeWithScope = 15
        
        /// `Int32`
        case int32 = 16
        
        /// Timestamp as milliseconds since UNIX Epoch Time
        case timestamp = 17
        
        /// `Int64`
        case int64 = 18
        
        /// The min-key
        case minKey = -1
        
        /// The max-key
        case maxKey = 127
    }
    
    /// Returns a Document that represents this AQT as a Query/Filter
    public var document: Document {
        switch self {
        case .typeof(let key, let type):
            if type == .number {
                let aqt = AQT.or([
                                  .typeof(key: key, type: .double),
                                  .typeof(key: key, type: .int32),
                                  .typeof(key: key, type: .int64)
                                  ])
                return aqt.document
                
            } else {
                return [key: ["$type": type.rawValue] as Document]
            }
        case .exactly(let doc):
            return doc
        case .valEquals(let key, let val):
            return [key: ["$eq": val] as Document]
        case .valNotEquals(let key, let val):
            return [key: ["$ne": val] as Document]
        case .greaterThan(let key, let val):
            return [key: ["$gt": val] as Document]
        case .greaterThanOrEqual(let key, let val):
            return [key: ["$gte": val] as Document]
        case .smallerThan(let key, let val):
            return [key: ["$lt": val] as Document]
        case .smallerThanOrEqual(let key, let val):
            return [key: ["$lte": val] as Document]
        case .and(let aqts):
            let expressions = aqts.map{ $0.document }
            
            return ["$and": Document(array: expressions) ]
        case .or(let aqts):
            let expressions = aqts.map{ $0.document }
            
            return ["$or": Document(array: expressions) ]
        case .not(let aqt):
            return ["$not": aqt.document]
        case .contains(let key, let val, let options):
            return [key: ((try? RegularExpression(pattern: val, options: options)) ?? Null()) as ValueConvertible] as Document
        case .startsWith(let key, let val):
            return [key: ((try? RegularExpression(pattern: "^" + val, options: .anchorsMatchLines)) ?? Null()) as ValueConvertible]
        case .endsWith(let key, let val):
            return [key: ((try? RegularExpression(pattern: val + "$", options: .anchorsMatchLines)) ?? Null()) as ValueConvertible]
        case .nothing:
            return []
        }
    }
    
    /// Whether the type in `key` is equal to the AQTType https://docs.mongodb.com/manual/reference/operator/query/type/#op._S_type
    case typeof(key: String, type: AQTType)
    
    /// Does the `Value` within the `key` match this `Value`
    case valEquals(key: String, val: ValueConvertible)
    
    /// The `Value` within the `key` does not match this `Value`
    case valNotEquals(key: String, val: ValueConvertible)
    
    /// Whether the `Value` within the `key` is greater than this `Value`
    case greaterThan(key: String, val: ValueConvertible)
    
    /// Whether the `Value` within the `key` is greater than or equal to this `Value`
    case greaterThanOrEqual(key: String, val: ValueConvertible)
    
    /// Whether the `Value` within the `key` is smaller than this `Value`
    case smallerThan(key: String, val: ValueConvertible)
    
    /// Whether the `Value` within the `key` is smaller than or equal to this `Value`
    case smallerThanOrEqual(key: String, val: ValueConvertible)
    
    /// Whether all `AQT` Conditions are correct
    case and([AQT])
    
    /// Whether any of these `AQT` conditions is correct
    case or([AQT])
    
    /// Whether none of these `AQT` conditions are correct
    case not(AQT)
    
    /// Whether nothing needs to be matched. Is always true and just a placeholder
    case nothing
    
    /// Whether the String value within the `key` contains this `String`.
    case contains(key: String, val: String, options: RegularExpression.Options)
    
    /// Whether the String value within the `key` starts with this `String`.
    case startsWith(key: String, val: String)
    
    /// Whether the String value within the `key` ends with this `String`.
    case endsWith(key: String, val: String)
    
    case exactly(Document)
}

/// A `Query` that consists of an `AQT` statement
public struct Query: ExpressibleByDictionaryLiteral, ValueConvertible {
    /// The `Document` that can be sent to the MongoDB Server as a query/filter
    public func makeBSONPrimitive() -> BSONPrimitive {
        return self.queryDocument
    }

    public init(dictionaryLiteral elements: (String, ValueConvertible)...) {
        self.aqt = .exactly(Document(dictionaryElements: elements))
    }
    
    /// The `Document` that can be sent to the MongoDB Server as a query/filter
    public var queryDocument: Document {
        return aqt.document
    }
    
    /// The `AQT` statement that's used as a query/filter
    public var aqt: AQT
    
    /// Initializes a `Query` with an `AQT` filter
    public init(aqt: AQT) {
        self.aqt = aqt
    }
    
    public init(_ document: Document) {
        self.aqt = .exactly(document)
    }
}

/// Allows matching this `Document` against a `Query`
extension Document {
    /// Filters the operators so that it's cleaner to compare Documents
    /// 
    /// TODO: Make this not necessary any more by improving the `on` event listener
    private func filterOperators() -> Document {
        var doc: Document = [:]
        
        for (k, v) in self {
            if k.characters.first == "$", let v: Document = v.documentValue {
                for (k2, v2) in v {
                    doc[k2] = v2
                }
            } else {
                doc[k] = v
            }
        }
        
        return doc
    }
}

public struct Pipeline: ExpressibleByArrayLiteral {
    var document: Document
    
    /// A stage in the aggregate
    public enum Stage: ValueConvertible {
        /// Takes a `Projection` that defines the inclusions or the exclusion of _id
        /// 
        /// For more details: https://docs.mongodb.com/manual/reference/operator/aggregation/project/#pipe._S_project
        case project(Projection)
        
        /// Filters the documents to pass only the documents that match the specified condition(s) to the next pipeline stage as defined in the provided `Query`
        case match(Query)
        
        /// Limits the returned results to the provided `Int` of results
        ///
        /// For more details: https://docs.mongodb.com/manual/reference/operator/aggregation/limit/#pipe._S_limit
        case limit(Int)
        
        /// Takes the documents returned by the aggregation pipelien and writes them to a specified collection. This `Stage` must be the last stage in the pipeline.
        ///
        /// For more details: https://docs.mongodb.com/manual/reference/operator/aggregation/out/#pipe._S_out
        case out(collection: String)
        
        /// Performs a left outer join to an unsharded collection in the same database to filter in documents from the “joined” collection for processing
        ///
        /// fromCollection is an unshaded collection in the same database to perform the join with
        ///
        /// localField is the field from the input documents into the lookup stage
        ///
        /// foreignField is the field in the `fromCollection`
        ///
        /// as is the name of the array to add to the input documents. The array will contain the matching Documents from the `fromCollection` collection. Will overwrite the existing key if there is one.
        ///
        /// For more details: https://docs.mongodb.com/manual/reference/operator/aggregation/lookup/#pipe._S_lookup
        case lookup(fromCollection: String, localfield: String, foreignField: String, as: String)
        
        /// Sorts all input documents and puts them in the pipeline in the sorted order
        ///
        /// For more details: https://docs.mongodb.com/manual/reference/operator/aggregation/sort/#pipe._S_sort
        case sort(Sort)
        
        /// Randomly selects N Documents from the aggregation pipeline input where N is the inputted size.
        ///
        /// For more details: https://docs.mongodb.com/manual/reference/operator/aggregation/sample/#pipe._S_sample
        case sample(size: Int)
        
        /// For more information: https://docs.mongodb.com/manual/reference/operator/aggregation/unwind/#pipe._S_unwind
        case unwind(path: String, includeArrayIndex: String?, preserveNullAndEmptyBooleans: Bool?)
        
        /// Skips over the specified number of documents that pass into the stage and passes the remaining documents to the next stage in the pipeline.
        case skip(Int)
        
        /// Creates a geoNear aggregate with the provided options as described [here](https://docs.mongodb.com/manual/reference/operator/aggregation/geoNear/#pipe._S_geoNear)
        case geoNear(options: Document)
        
        case group(Document)
        
        /// Creates a custom aggregate stage using the provided Document
        ///
        /// Used for aggregations that MongoKitten does not support
        case custom(Document)
        
        public func makeBSONPrimitive() -> BSONPrimitive {
            switch self {
            case .custom(let doc):
                return doc
            case .project(let projection):
                return [
                    "$project": projection.makeBSONPrimitive()
                ] as Document
            case .match(let query):
                return [
                    "$match": query
                ] as Document
            case .limit(let limit):
                return [
                    "$limit": limit
                ] as Document
            case .out(let collection):
                return ["$out": collection] as Document
            case .lookup(let from, let localField, let foreignField, let namedAs):
                return ["$lookup": [
                    "from": from,
                    "localField": localField,
                    "foreignField": foreignField,
                    "as": namedAs
                    ] as Document
                ] as Document
            case .sort(let sort):
                return ["$sort": sort] as Document
            case .sample(let size):
                return ["$sample": [
                        ["$size": size] as Document
                    ] as Document
                ] as Document
            case .unwind(let path, let includeArrayIndex, let preserveNullAndEmptyArrays):
                let unwind: ValueConvertible
                
                if let includeArrayIndex = includeArrayIndex {
                    var unwind1 = [
                        "path": path
                    ] as Document
                    
                    unwind1["includeArrayIndex"] = includeArrayIndex
                    
                    if let preserveNullAndEmptyArrays = preserveNullAndEmptyArrays {
                        unwind1["preserveNullAndEmptyArrays"] = preserveNullAndEmptyArrays
                    }
                    
                    unwind = unwind1
                } else if let preserveNullAndEmptyArrays = preserveNullAndEmptyArrays {
                    unwind = [
                        "path": path,
                        "preserveNullAndEmptyArrays": preserveNullAndEmptyArrays
                    ] as Document
                } else {
                    unwind = path
                }
                
                return [
                    "$unwind": unwind
                ] as Document
            case .skip(let amount):
                return ["$skip": amount] as Document
            case .geoNear(let options):
                return ["$geoNear": options] as Document
            case .group(let document):
                return ["$group": document] as Document
            }
        }
    }
    
    public init(_ document: Document) {
        self.document = document
    }

    public init(arrayLiteral elements: Stage...) {
        self.document = Document(array: elements.map {
            $0
        })
    }
}
