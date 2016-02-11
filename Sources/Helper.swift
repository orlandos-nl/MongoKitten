//
//  Helper.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 10/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation

postfix operator * {}

/// Will convert an ArraySlice<UInt8> to [UInt8]
internal postfix func * (slice: ArraySlice<UInt8>) -> [UInt8] {
    return Array(slice)
}