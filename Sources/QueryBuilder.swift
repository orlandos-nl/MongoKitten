//
//  Query.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 15-03-16.
//  Copyright © 2016 OpenKitten. All rights reserved.
//

import Foundation
import BSON

// MARK: Equations

/// Equals
public func ==(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .valEquals(key: key, val: ~pred))
}

/// MongoDB: `$ne`
public func !=(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .valNotEquals(key: key, val: ~pred))
}

// MARK: Comparisons

/// MongoDB: `$gt`. Used like native swift `>`
///
/// Checks whether the `Value` in `key` is larger than the `Value` provided
///
/// - returns: A new `Query` requiring the `Value` in the `key` to be larger than the provided `Value`
public func >(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .greaterThan(key: key, val: ~pred))
}

/// MongoDB: `$gte`. Used like native swift `>=`
///
/// Checks whether the `Value` in `key` is larger than or equal to the `Value` provided
///
/// - returns: A new `Query` requiring the `Value` in the `key` to be larger than or equal to the provided `Value`
public func >=(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .greaterThanOrEqual(key: key, val: ~pred))
}

/// MongoDB: `$lt`. Used like native swift `<`
///
/// Checks whether the `Value` in `key` is smaller than the `Value` provided
///
/// - returns: A new `Query` requiring the `Value` in the `key` to be smaller than the provided `Value`
public func <(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .smallerThan(key: key, val: ~pred))
}

/// MongoDB: `$lte`. Used like native swift `<=`
///
/// Checks whether the `Value` in `key` is smaller than or equal to the `Value` provided
///
/// - returns: A new `Query` requiring the `Value` in the `key` to be smaller than or equal to the provided `Value`
public func <=(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .smallerThanOrEqual(key: key, val: ~pred))
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

public func &=(lhs: QueryProtocol, rhs: QueryProtocol) -> Document {
    var lhs = lhs.data
    
    for (key, value) in rhs.data {
        lhs[key] = value
    }
    
    return lhs
}

/// A protocol that allows other types to be used as a `Value` replacement
public protocol ValueProtocol {
    /// You have to be able to provide a BSON `Value`
    var val: Value { get }
}

/// Makes it so that a normal BSON `Value` can be used in statements
extension Value: ValueProtocol {
    /// The `Value` in `Value` is `self`
    public var val: Value {
        return self
    }
}

/// Abstract Query Tree.
///
/// Made to be easily readable/usable so that an `AQT` instance can be easily translated to a `Document` as a Query or even possibly `SQL` in the future.
public indirect enum AQT {
    /// The types we support as raw `Int32` values
    ///
    /// The raw values are defined in https://docs.mongodb.com/manual/reference/operator/query/type/#op._S_type
    public enum AQTType: Int32 {
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
                return [key: ["$type": ~type.rawValue]]
            }
        case .valEquals(let key, let val):
            return [key: ["$eq": val.val]]
        case .valNotEquals(let key, let val):
            return [key: ["$ne": val.val]]
        case .greaterThan(let key, let val):
            return [key: ["$gt": val.val]]
        case .greaterThanOrEqual(let key, let val):
            return [key: ["$gte": val.val]]
        case .smallerThan(let key, let val):
            return [key: ["$lt": val.val]]
        case .smallerThanOrEqual(let key, let val):
            return [key: ["$lte": val.val]]
        case .and(let aqts):
            let expressions = aqts.map{ Value.document($0.document) }
            
            return ["$and": .array(Document(array: expressions)) ]
        case .or(let aqts):
            let expressions = aqts.map{ Value.document($0.document) }
            
            return ["$or": .array(Document(array: expressions)) ]
        case .not(let aqt):
            return ["$not": ~aqt.document]
        case .nothing:
            return []
        }
    }
    
    /// Whether the type in `key` is equal to the AQTType https://docs.mongodb.com/manual/reference/operator/query/type/#op._S_type
    case typeof(key: String, type: AQTType)
    
    /// Does the `Value` within the `key` match this `Value`
    case valEquals(key: String, val: ValueProtocol)
    
    /// The `Value` within the `key` does not match this `Value`
    case valNotEquals(key: String, val: ValueProtocol)
    
    /// Whether the `Value` within the `key` is greater than this `Value`
    case greaterThan(key: String, val: ValueProtocol)
    
    /// Whether the `Value` within the `key` is greater than or equal to this `Value`
    case greaterThanOrEqual(key: String, val: ValueProtocol)
    
    /// Whether the `Value` within the `key` is smaller than this `Value`
    case smallerThan(key: String, val: ValueProtocol)
    
    /// Whether the `Value` within the `key` is smaller than or equal to this `Value`
    case smallerThanOrEqual(key: String, val: ValueProtocol)
    
    /// Whether all `AQT` Conditions are correct
    case and([AQT])
    
    /// Whether any of these `AQT` conditions is correct
    case or([AQT])
    
    /// Whether none of these `AQT` conditions are correct
    case not(AQT)
    
    /// Whether nothing needs to be matched. Is always true and just a placeholder
    case nothing
}

/// The protocol all queries need to comply to
public protocol QueryProtocol {
    /// They need to return a `Document` that will be used for matching
    var data: Document { get }
}

/// A `Query` that consists of an `AQT` statement
public struct Query: QueryProtocol {
    /// The `Document` that can be sent to the MongoDB Server as a query/filter
    public var data: Document {
        return aqt.document
    }
    
    /// The `AQT` statement that's used as a query/filter
    public var aqt: AQT
    
    /// Initializes a `Query` with an `AQT` filter
    public init(aqt: AQT) {
        self.aqt = aqt
    }
}

/// Makes a raw `Document` usable as `Query`
extension Document: QueryProtocol {
    /// Makes a raw `Document` usable as `Query`
    public var data: Document {
        return self
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
    
    /// Checks if a `Document` matches the given `Query`
    /// 
    /// - parameter query: The `Query` to match this `Document` against
    ///
    /// - returns: Whether this `Document` matches the `Query`
    public func matches(query q: Query) -> Bool {
        let doc = self.filterOperators()
        
        switch q.aqt {
        case .typeof(let key, let type):
            return doc[key].typeNumber == type.rawValue
        case .valEquals(let key, let val):
            return doc[key] == val.val
        case .valNotEquals(let key, let val):
            return doc[key] != val.val
        case .greaterThan(let key, let val):
            switch doc[key] {
            case .double(let d):
                if let d2 = val.val.int32Value {
                    return d > Double(d2)
                } else if let d2 = val.val.doubleValue {
                    return d > d2
                } else if let d2 = val.val.int64Value {
                    return d > Double(d2)
                }
                
                return false
            case .int32(let d):
                if let d2 = val.val.int32Value {
                    return d > d2
                } else if let d2 = val.val.doubleValue {
                    return Double(d) > d2
                } else if let d2 = val.val.int64Value {
                    return Int64(d) > d2
                }
                
                return false
            case .int64(let d):
                if let d2 = val.val.int32Value {
                    return d > Int64(d2)
                } else if let d2 = val.val.doubleValue {
                    return Double(d) > d2
                } else if let d2 = val.val.int64Value {
                    return d > d2
                }
                
                return false
            default:
                return false
            }
        case .greaterThanOrEqual(let key, let val):
            switch doc[key] {
            case .double(let d):
                if let d2 = val.val.int32Value {
                    return d >= Double(d2)
                } else if let d2 = val.val.doubleValue {
                    return d >= d2
                } else if let d2 = val.val.int64Value {
                    return d >= Double(d2)
                }
                
                return false
            case .int32(let d):
                if let d2 = val.val.int32Value {
                    return d >= d2
                } else if let d2 = val.val.doubleValue {
                    return Double(d) >= d2
                } else if let d2 = val.val.int64Value {
                    return Int64(d) >= d2
                }
                
                return false
            case .int64(let d):
                if let d2 = val.val.int32Value {
                    return d >= Int64(d2)
                } else if let d2 = val.val.doubleValue {
                    return Double(d) >= d2
                } else if let d2 = val.val.int64Value {
                    return d >= d2
                }
                
                return false
            default:
                return false
            }
        case .smallerThan(let key, let val):
            switch doc[key] {
            case .double(let d):
                if let d2 = val.val.int32Value {
                    return d < Double(d2)
                } else if let d2 = val.val.doubleValue {
                    return d < d2
                } else if let d2 = val.val.int64Value {
                    return d <  Double(d2)
                }
                
                return false
            case .int32(let d):
                if let d2 = val.val.int32Value {
                    return d < d2
                } else if let d2 = val.val.doubleValue {
                    return Double(d) < d2
                } else if let d2 = val.val.int64Value {
                    return Int64(d) < d2
                }
                
                return false
            case .int64(let d):
                if let d2 = val.val.int32Value {
                    return d < Int64(d2)
                } else if let d2 = val.val.doubleValue {
                    return Double(d) < d2
                } else if let d2 = val.val.int64Value {
                    return d < d2
                }
                
                return false
            default:
                return false
            }
        case .smallerThanOrEqual(let key, let val):
            switch doc[key] {
            case .double(let d):
                if let d2 = val.val.int32Value {
                    return d <= Double(d2)
                } else if let d2 = val.val.doubleValue {
                    return d <= d2
                } else if let d2 = val.val.int64Value {
                    return d <= Double(d2)
                }
                
                return false
            case .int32(let d):
                if let d2 = val.val.int32Value {
                    return d <= d2
                } else if let d2 = val.val.doubleValue {
                    return Double(d) <= d2
                } else if let d2 = val.val.int64Value {
                    return Int64(d) <= d2
                }
                
                return false
            case .int64(let d):
                if let d2 = val.val.int32Value {
                    return d <= Int64(d2)
                } else if let d2 = val.val.doubleValue {
                    return Double(d) <= d2
                } else if let d2 = val.val.int64Value {
                    return d <= d2
                }
                
                return false
            default:
                return false
            }
        case .and(let aqts):
            for aqt in aqts {
                guard self.matches(query: Query(aqt: aqt)) else {
                    return false
                }
            }
            
            return true
        case .or(let aqts):
            for aqt in aqts {
                if self.matches(query: Query(aqt: aqt)) {
                    return true
                }
            }
            
            return false
        case .not(let aqt):
            return !self.matches(query: Query(aqt: aqt))
        case .nothing:
            return true
        }
    }
}

/// Adds returning the type as Int32
extension Value {
    /// Returns the type as Int32 defined in https://docs.mongodb.com/manual/reference/operator/query/type/#op._S_type
    var typeNumber: Int32 {
        switch self {
        case .double(_):
            return 1
        case .string(_):
            return 2
        case .document(_):
            return 3
        case .array(_):
            return 4
        case .binary(_, _):
            return 5
        case .objectId(_):
            return 7
        case .boolean(_):
            return 8
        case .dateTime(_):
            return 9
        case .null:
            return 10
        case .regularExpression(_, _):
            return 11
        case .javascriptCode(_):
            return 11
        case .javascriptCodeWithScope(_, _):
            return 13
        case .int32(_):
            return 16
        case .timestamp(_):
            return 17
        case .int64(_):
            return 18
        case .maxKey:
            return 127
        case .minKey:
            return -1
        case .nothing:
            return -2
        }
    }
}
