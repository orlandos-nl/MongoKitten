//
//  Query.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 15-03-16.
//  Copyright © 2016 PlanTeam. All rights reserved.
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
/// MongoDB: `$gt`
public func >(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .greaterThan(key: key, val: ~pred))
}

/// MongoDB: `$gte`
public func >=(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .greaterThanOrEqual(key: key, val: ~pred))
}

/// MongoDB: `$lt`
public func <(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .smallerThan(key: key, val: ~pred))
}

/// MongoDB: `$lte`
public func <=(key: String, pred: ValueConvertible) -> Query {
    return Query(aqt: .smallerThanOrEqual(key: key, val: ~pred))
}

/// Appends `rhs` to `lhs`
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

/// MongoDB: `$or`
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

public prefix func !(query: Query) -> Query {
    return Query(aqt: .not(query.aqt))
}

public func &=(lhs: QueryProtocol, rhs: QueryProtocol) -> Document {
    return lhs.data + rhs.data
}

public protocol AQTValue {
    var val: Value { get }
}

extension Value: AQTValue {
    public var val: Value {
        return self
    }
}

public indirect enum AQT {
    public enum AQTType {
        case string
        case number
        case int32
        case int64
        case double
        case null
        case document
        case array
        case binary
        case objectId
        case regex
        case jsCode
        case jsCodeWithScope
        case timestamp
        case dateTime
        case minKey
        case maxKey
    }
    
    public var document: Document {
        switch self {
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
    
    case valEquals(key: String, val: AQTValue)
//    case typeEquals(key: String, type: AQTType)
    case valNotEquals(key: String, val: AQTValue)
//    case typeNotEquals(key: String, type: AQTType)
    
    case greaterThan(key: String, val: AQTValue)
    case greaterThanOrEqual(key: String, val: AQTValue)
    case smallerThan(key: String, val: AQTValue)
    case smallerThanOrEqual(key: String, val: AQTValue)
    
    case and([AQT])
    case or([AQT])
    case not(AQT)
    case nothing
}

public protocol QueryProtocol {
    var data: Document { get }
}

public struct Query: QueryProtocol {
    public var data: Document {
        return aqt.document
    }
    
    public var aqt: AQT
    
    public init(aqt: AQT) {
        self.aqt = aqt
    }
}

extension Document: QueryProtocol {
    public var data: Document {
        return self
    }
}

extension Document {
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
    
    public func matches(query: Query) -> Bool {
        let doc = self.filterOperators()
        
        switch query.aqt {
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