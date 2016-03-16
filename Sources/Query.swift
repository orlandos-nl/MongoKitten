//
//  Query.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 15-03-16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

infix operator ~> {} // $in
infix operator !~> {} // $nin
infix operator => {} // $all

func test() {
    let _: Query = "tracks" => [22,23,34]
}

// MARK: Equations
/// Equals
public func ==(key: String, pred: BSONElement) -> Query {
    return Query(data: [key: pred])
}

/// MongoDB: `$ne`
public func !=(key: String, pred: BSONElement) -> Query {
    return Query(data: [key: *["$ne": pred]])
}

// MARK: Comparisons
/// MongoDB: `$gt`
public func >(key: String, pred: BSONElement) -> Query {
    return Query(data: [key: *["$gt": pred]])
}

/// MongoDB: `$gte`
public func >=(key: String, pred: BSONElement) -> Query {
    return Query(data: [key: *["$gte": pred]])
}

/// MongoDB: `$lt`
public func <(key: String, pred: BSONElement) -> Query {
    return Query(data: [key: *["$lt": pred]])
}

/// MongoDB: `$lte`
public func <=(key: String, pred: BSONElement) -> Query {
    return Query(data: [key: *["$lte": pred]])
}

/// Appends `rhs` to `lhs`
public func &&(lhs: Query, rhs: Query) -> Query {
    return Query(data: lhs.data + rhs.data)
}

/// MongoDB: `$or`
public func ||(lhs: Query, rhs: Query) -> Query {
    if let orDoc = lhs.data["$or"]?.documentValue  {
        let newOr = orDoc + *[rhs.data]
        
        var lhs = lhs
        lhs.data["$or"] = newOr
        return lhs
    } else {
        return Query(data: ["$or": *[lhs.data, rhs.data]])
    }
}

/// MongoDB: `$in`
public func ~>(key: String, pred: [BSONElement]) -> Query {
    return Query(data: [key: *["$in": Document(array: pred)]])
}

/// MongoDB: `$nin`
public func !~>(key: String, pred: [BSONElement]) -> Query {
    return Query(data: [key: *["$nin": Document(array: pred)]])
}

/// MongoDB: `$all`
public func =>(key: String, pred: [BSONElement]) -> Query {
    return Query(data: [key: *["$all": Document(array: pred)]])
}

public struct Query {
    internal var data: Document
}