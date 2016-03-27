//
//  Helper.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 10/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation

postfix operator * {}

/// Will convert an ArraySlice<Byte> to [Byte]
internal postfix func * (slice: ArraySlice<Byte>) -> [Byte] {
    return Array(slice)
}

internal func replaceOccurrences(in string: String, where matching: String, with replacement: String) -> String {
    #if os(Linux)
        return string.stringByReplacingOccurrencesOf(matching, withString: replacement)
    #else
        return string.replacingOccurrences(of: matching, with: replacement)
    #endif
}