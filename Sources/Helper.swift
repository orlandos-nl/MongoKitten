//
//  Helper.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 10/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation

postfix operator * {}
internal postfix func * (slice: ArraySlice<UInt8>) -> [UInt8] {
    return Array(slice)
}