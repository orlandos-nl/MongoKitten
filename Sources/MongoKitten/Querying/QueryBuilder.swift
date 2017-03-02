//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Foundation
import BSON
import GeoJSON

#if os(macOS)
    /// RegularExpression is named differently on Linux. Linux is our primary target.
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

/// Adds two queries to create a new Document (which can be converted to a Query)
public func &=(lhs: Query, rhs: Query) -> Document {
    var lhs = lhs.queryDocument
    
    for (key, value) in rhs.queryDocument {
        lhs[raw: key] = value
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
        /// -
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
        
        /// High precision decimal
        case decimal128 = 19
        
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
        case .containsElement(let key, let aqt):
            return [key: ["$elemMatch": aqt.document] as Document]
        case .and(let aqts):
            let expressions = aqts.map{ $0.document }
            
            return ["$and": Document(array: expressions) ]
        case .or(let aqts):
            let expressions = aqts.map{ $0.document }
            
            return ["$or": Document(array: expressions) ]
        case .not(let aqt):
            var query: Document = [:]
            
            for (key, value) in aqt.document {
                query[key] = [
                    "$not": value
                ]
            }
            
            return query
        case .contains(let key, let val, let options):
            return [key: ((try? RegularExpression(pattern: val, options: options)) ?? Null()) as ValueConvertible] as Document
        case .startsWith(let key, let val):
            return [key: ((try? RegularExpression(pattern: "^" + val, options: .anchorsMatchLines)) ?? Null()) as ValueConvertible]
        case .endsWith(let key, let val):
            return [key: ((try? RegularExpression(pattern: val + "$", options: .anchorsMatchLines)) ?? Null()) as ValueConvertible]
        case .nothing:
            return []
        case .near(let key, let point, let maxDistance, let minDistance):
            return GeometryOperator(key: key, operatorName: "$near", geometry: point, maxDistance: maxDistance, minDistance: minDistance).makeDocument()
        case .geoWithin(let key, let polygon):
            return GeometryOperator(key: key, operatorName: "$geoWithin", geometry: polygon).makeDocument()
        case .exists(key: let key):
            return [
                key: [ "$exists": true ] as Document
            ]
        case .geoIntersects(let key, let geometry):
            return GeometryOperator(key: key, operatorName: "$geoIntersects", geometry: geometry).makeDocument()
        case .nearSphere(let key, let point, let maxDistance, let minDistance):
            return GeometryOperator(key: key, operatorName: "$nearSphere", geometry: point, maxDistance: maxDistance, minDistance: minDistance).makeDocument()
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
    
    /// Whether a subdocument in the array within the `key` matches one of the queries/filters
    case containsElement(key: String, match: AQT)
    
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
    
    /// A literal Document
    case exactly(Document)
    
    /// Value at this key exists, even if it is `Null`
    case exists(key: String)

    /// Match all documents containing a `key` with geospatial data that is near the specified GeoJSON `Point`.
    ///
    /// - `key` the field name
    /// - `point` the GeoJSON Point
    /// - `maxDistance` : the maximum distance from the `point`, in meters
    /// - `minDistance` : the minimum distance from the `point`, in meters
    ///
    /// - SeeAlso : https://docs.mongodb.com/manual/reference/operator/query/near/
    case near(key: String, point: Point, maxDistance: Double, minDistance: Double)

    /// Match all documents containing a `key` with geospatial data that exists entirely within the specified `Polygon`.
    /// - `key` the field name
    /// - `polygon` the GeoJSON Polygon
    /// - SeeAlso : https://docs.mongodb.com/manual/reference/operator/query/geoWithin/
    case geoWithin(key: String, polygon: GeoJSON.Polygon)

    /// Match all documents containing a `key` with geospatial data that intersects with the specified shape.
    /// - `key` the field name
    /// - `geometry` the GeoJSON Geometry
    /// - SeeAlso : https://docs.mongodb.com/manual/reference/operator/query/geoIntersects/
    case geoIntersects(key: String, geometry: Geometry)

    /// Match all documents containing a `key` with geospatial data that is near the specified GeoJSON point using spherical geometry.
    ///
    /// - `point` the GeoJSON Point
    /// - `maxDistance` : the maximum distance from the `point`, in meters
    /// - `minDistance` : the minimum distance from the `point`, in meters
    ///
    /// - SeeAlso : https://docs.mongodb.com/manual/reference/operator/query/nearSphere/
    case nearSphere(key: String, point: Point,maxDistance: Double, minDistance: Double)
}

/// A `Query` that consists of an `AQT` statement
public struct Query: ExpressibleByDictionaryLiteral, ValueConvertible, ExpressibleByStringLiteral {
    /// Initializes this Query with a String literal for a text search
    public init(stringLiteral value: String) {
        self = .textSearch(forString: value)
    }
    
    /// Initializes this Query with a String literal for a text search
    public init(unicodeScalarLiteral value: String) {
        self = .textSearch(forString: value)
    }
    
    /// Initializes this Query with a String literal for a text search
    public init(extendedGraphemeClusterLiteral value: String) {
        self = .textSearch(forString: value)
    }
    
    /// Returns the Document state of this Query
    public func makeDocument() -> Document {
        return self.queryDocument
    }
    
    /// The `Document` that can be sent to the MongoDB Server as a query/filter
    public func makeBSONPrimitive() -> BSONPrimitive {
        return self.queryDocument
    }


    /// Creates a Query from a Dictionary Literal
    public init(dictionaryLiteral elements: (StringVariant, ValueConvertible?)...) {
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
    
    /// Initializes a Query from a Document and uses this Document as the Query
    public init(_ document: Document) {
        self.aqt = .exactly(document)
    }
    
    /// Creates a textSearch for a specified string
    public static func textSearch(forString string: String, language: String? = nil, caseSensitive: Bool = false, diacriticSensitive: Bool = false) -> Query {
        var textSearch: Document = ["$text": [
            "$search": string,
            "$caseSensitive": caseSensitive,
            "$diacriticSensitive": diacriticSensitive
            ] as Document
        ]
    
        if let language = language {
            textSearch["$language"] = language
        }
        
        return Query(textSearch)
    }
}
