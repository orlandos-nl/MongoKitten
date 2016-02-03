//
//  Helper.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 03/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON


postfix operator * {}
internal postfix func * (slice: ArraySlice<UInt8>) -> [UInt8] {
    return Array(slice)
}

/// Adds one document to the collection
/// Returns whether it has been successfully sent to the server
public func += (left: Collection, right: Document) -> Bool {
    do {
        try left.insert(right)
        return true
    } catch(_) {
        return false
    }
}

/// Adds all documents in the array to the collection
/// Returns whether it has been successfully sent to the server
infix operator ++= {}
public func ++= (left: Collection, right: [Document]) -> Bool {
    do {
        try left.insertAll(right)
        return true
    } catch(_) {
        return false
    }
}

/// Removed the first match with the given document from the collection
/// Returns whether it has been successfully sent to the server
public func -=(left: Collection, right: Document) -> Bool {
    do {
        try left.removeOne(right)
        return true
    } catch(_) {
        return false
    }
}

/// Removed all matches with the given document from the collection
/// Returns whether it has been successfully sent to the server
infix operator --= {}
public func --=(left: Collection, right: Document) -> Bool {
    do {
        try left.removeAll(right)
        return true
    } catch(_) {
        return false
    }
}