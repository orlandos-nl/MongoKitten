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
public func ==(key: String, pred: BSONElement) -> Query {
    return Query(data: [key: *["$eq": pred]])
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
    var queryDoc = lhs.data
    
    for (key, value) in rhs.data {
        guard let lhsDoc = lhs.data[key]?.documentValue, rhsDoc = value.documentValue else {
            return Query(data: lhs.data + rhs.data)
        }
        
        let newDoc = lhsDoc + rhsDoc
        queryDoc[key] = newDoc
    }
    
    return Query(data: queryDoc)
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


public func &=(lhs: inout Query, rhs: Document) {
    lhs.data += rhs
}

public func &=(lhs: inout Query, rhs: Query) {
    lhs = lhs && rhs
}

public func |=(lhs: inout Query, rhs: Query) {
    lhs = lhs || rhs
}

public func |=(lhs: inout Query, rhs: Document) {
    lhs = lhs || Query(data: rhs)
}

public struct Query {
    public var data: Document
    private init(data: Document) {
        self.data = data
    }
}