//
//  OperationCode.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation

internal enum OperationCode : Int32 {
    case Reply = 1, Message = 1000, Update = 2001, Insert = 2002, Query = 2004, GetMore = 2005, Delete = 2006, KillCursors = 2007
}