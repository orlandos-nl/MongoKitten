//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2018 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Foundation
import BSON

// MARK: Equations

/// **If `pred` is not `nil`:** `$eq` - Specifies equality condition. The `$eq` operator matches documents where the value of a field equals the specified value.
/// **If `pred` is `nil`:** `{$exists: false}` - the query returns only the documents that do not contain the field.
///
/// - see: https://docs.mongodb.com/manual/reference/operator/query/eq/index.html
/// - see: https://docs.mongodb.com/manual/reference/operator/query/exists/index.html
public func == (field: String, pred: BSON.Primitive?) -> Query {
    if let pred = pred {
        return .valEquals(field: field, val: pred)
    } else {
        return .exists(field: field, exists: false)
    }
}

/// **If `pred` is not `nil`:** `$ne` - `$ne` selects the documents where the value of the field is not equal to the specified value. This includes documents that do not contain the field.
/// **If `pred` is `nil`:** `{$exists: true}` - matches the documents that contain the field, including documents where the field value is null.
///
/// - see: https://docs.mongodb.com/manual/reference/operator/query/ne/index.html
/// - see: https://docs.mongodb.com/manual/reference/operator/query/exists/index.html
public func != (field: String, pred: BSON.Primitive?) -> Query {
    if let pred = pred {
        return .valNotEquals(field: field, val: pred)
    } else {
        return .exists(field: field, exists: true)
    }
}

// MARK: Comparisons

/// $gt selects those documents where the value of the field is greater than (i.e. >) the specified value.
///
/// For most data types, comparison operators only perform comparisons on fields where the BSON type matches the query value’s type. MongoDB supports limited cross-BSON comparison through Type Bracketing.
///
/// - see: https://docs.mongodb.com/manual/reference/operator/query/gt/index.html
public func > (field: String, pred: BSON.Primitive) -> Query {
    return .greaterThan(field: field, val: pred)
}

/// $gte selects the documents where the value of the field is greater than or equal to (i.e. >=) a specified value (e.g. value.)
///
/// For most data types, comparison operators only perform comparisons on fields where the BSON type matches the query value’s type. MongoDB supports limited cross-BSON comparison through Type Bracketing.
///
/// - see: https://docs.mongodb.com/manual/reference/operator/aggregation/gte/index.html
public func >= (field: String, pred: BSON.Primitive) -> Query {
    return .greaterThanOrEqual(field: field, val: pred)
}

/// $lt selects the documents where the value of the field is less than (i.e. <) the specified value.
///
/// For most data types, comparison operators only perform comparisons on fields where the BSON type matches the query value’s type. MongoDB supports limited cross-BSON comparison through Type Bracketing.
///
/// - see: https://docs.mongodb.com/manual/reference/operator/query/lt/index.html
public func < (field: String, pred: BSON.Primitive) -> Query {
    return .smallerThan(field: field, val: pred)
}

/// $lte selects the documents where the value of the field is less than or equal to (i.e. <=) the specified value.
///
/// For most data types, comparison operators only perform comparisons on fields where the BSON type matches the query value’s type. MongoDB supports limited cross-BSON comparison through Type Bracketing.
///
/// - see: https://docs.mongodb.com/manual/reference/operator/query/lte/index.html
public func <= (field: String, pred: BSON.Primitive) -> Query {
    return .smallerThanOrEqual(field: field, val: pred)
}

/// $and performs a logical AND operation on an array of two or more expressions (e.g. <expression1>, <expression2>, etc.) and selects the documents that satisfy all the expressions in the array. The $and operator uses short-circuit evaluation. If the first expression (e.g. <expression1>) evaluates to false, MongoDB will not evaluate the remaining expressions.
///
/// - see: https://docs.mongodb.com/manual/reference/operator/query/and/index.html
public func && (lhs: Query, rhs: Query) -> Query {
    switch (lhs, rhs) {
    case (.and(var a), .and(let b)):
        a.append(contentsOf: b)
        return .and(a)
    case (.nothing, let query), (let query, .nothing):
        return query
    case (.and(var a), let other), (let other, .and(var a)):
        a.append(other)
        return .and(a)
    default:
        return .and([lhs, rhs])
    }
}

/// The $or operator performs a logical OR operation on an array of two or more <expressions> and selects the documents that satisfy at least one of the <expressions>.
///
/// - see: https://docs.mongodb.com/manual/reference/operator/query/or/index.html
public func || (lhs: Query, rhs: Query) -> Query {
    if case .or(var  a) = lhs, case .or(let b) = rhs {
        a.append(contentsOf: b)
        return .or(a)
    } else if case .or(var a) = lhs {
        a.append(rhs)
        return .or(a)
    } else if case .or(var b) = rhs {
        b.append(lhs)
        return .or(b)
    } else {
        return .or([lhs, rhs])
    }
}

/// $not performs a logical NOT operation on the specified <operator-expression> and selects the documents that do not match the <operator-expression>. This includes documents that do not contain the field.
///
/// - see: https://docs.mongodb.com/manual/reference/operator/query/not/index.html
public prefix func ! (query: Query) -> Query {
    return .not(query)
}

/// $and performs a logical AND operation on an array of two or more expressions (e.g. <expression1>, <expression2>, etc.) and selects the documents that satisfy all the expressions in the array. The $and operator uses short-circuit evaluation. If the first expression (e.g. <expression1>) evaluates to false, MongoDB will not evaluate the remaining expressions.
///
/// - see: https://docs.mongodb.com/manual/reference/operator/query/and/index.html
public func &&= (lhs: inout Query, rhs: Query) {
    lhs = lhs && rhs
}

infix operator &&=
infix operator ||=

/// The $or operator performs a logical OR operation on an array of two or more <expressions> and selects the documents that satisfy at least one of the <expressions>.
///
/// - see: https://docs.mongodb.com/manual/reference/operator/query/or/index.html
public func ||= (lhs: inout Query, rhs: Query) {
    lhs = lhs || rhs
}

/// Abstract Query Tree.
///
/// Made to be easily readable/usable so that an `AQT` instance can be easily translated to a `Document` as a Query or even possibly `SQL` in the future.
public indirect enum Query: Codable, ExpressibleByDictionaryLiteral {
    /// The types we support as raw `Int32` values
    ///
    /// The raw values are defined in https://docs.mongodb.com/manual/reference/operator/query/type/#op._S_type
    public enum QueryType: Int32 {
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

    /// Returns a Document that represents this Query
    public var document: Document {
        switch self {
        case .typeof(let field, let type):
            if type == .number {
                let aqt = Query.or([
                    .typeof(field: field, type: .double),
                    .typeof(field: field, type: .int32),
                    .typeof(field: field, type: .int64)
                    ])
                return aqt.document

            } else {
                // TODO: Check if we can remove the `as Document` here and below by changing BSON
                return [field: ["$type": type.rawValue] as Document]
            }
        case .custom(let doc):
            return doc
        case .valEquals(let field, let val):
            return [field: ["$eq": val] as Document]
        case .valNotEquals(let field, let val):
            return [field: ["$ne": val] as Document]
        case .greaterThan(let field, let val):
            return [field: ["$gt": val] as Document]
        case .greaterThanOrEqual(let field, let val):
            return [field: ["$gte": val] as Document]
        case .smallerThan(let field, let val):
            return [field: ["$lt": val] as Document]
        case .smallerThanOrEqual(let field, let val):
            return [field: ["$lte": val] as Document]
        case .containsElement(let field, let aqt):
            return [field: ["$elemMatch": aqt.document] as Document]
        case .and(let aqts):
            let expressions = aqts.map { $0.document }

            return ["$and": expressions]
        case .or(let aqts):
            let expressions = aqts.map { $0.document }

            return ["$or": expressions]
        case .not(let aqt):
            // TODO: Fix `!("a" == 1 || "b" == 1)` - this implementation generates an invalid query
            var query = Document()
            
            for (key, value) in aqt.document {
                query[key] = [
                    "$not": value
                ] as Document
            }

            return query
        case .nothing:
            return [:]
        case .in(let field, let array):
            return [field: ["$in": Document(array: array)] as Document]
        case .exists(let field, let exists):
            return [
                field: [ "$exists": exists ] as Document
            ]
        }
    }

    /// Whether the type in `key` is equal to the AQTType https://docs.mongodb.com/manual/reference/operator/query/type/#op._S_type
    case typeof(field: String, type: QueryType)

    /// Does the `Value` within the `key` match this `Value`
    case valEquals(field: String, val: BSON.Primitive)

    /// The `Value` within the `key` does not match this `Value`
    case valNotEquals(field: String, val: BSON.Primitive)

    /// Whether the `Value` within the `key` is greater than this `Value`
    case greaterThan(field: String, val: BSON.Primitive)

    /// Whether the `Value` within the `key` is greater than or equal to this `Value`
    case greaterThanOrEqual(field: String, val: BSON.Primitive)

    /// Whether the `Value` within the `key` is smaller than this `Value`
    case smallerThan(field: String, val: BSON.Primitive)

    /// Whether the `Value` within the `key` is smaller than or equal to this `Value`
    case smallerThanOrEqual(field: String, val: BSON.Primitive)

    /// Whether a subdocument in the array within the `key` matches one of the queries/filters
    case containsElement(field: String, match: Query)

    /// Whether all `AQT` Conditions are correct
    case and([Query])

    /// Whether any of these `AQT` conditions is correct
    case or([Query])

    /// Whether none of these `AQT` conditions are correct
    case not(Query)

    /// Whether nothing needs to be matched. Is always true and just a placeholder
    case nothing

    /// A custom query
    case custom(Document)

    /// Value at this key exists, even if it is `Null`
    case exists(field: String, exists: Bool)

    /// Value is one of the given values
    case `in`(field: String, in: [BSON.Primitive])
    
    public init(from decoder: Decoder) throws {
        self = .custom(try Document(from: decoder))
    }
    
    /// Initializes an empty query
    public init() {
        self = .nothing
    }
    
    /// Creates a query from a dictionary literal
    public init(dictionaryLiteral elements: (String, PrimitiveConvertible)...) {
        if elements.count == 0 {
            self = .nothing
        } else {
            self = .custom(Document(elements: elements.compactMap { key, value in
                guard let primitive = value.makePrimitive() else {
                    return nil // continue
                }
                
                return (key, primitive)
            }))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        try document.encode(to: encoder)
    }
}
