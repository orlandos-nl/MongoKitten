//
//  Message.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation


public protocol Message {
    var collection: Collection {get}
    
    var requestID: Int32 {get}
    var responseTo: Int32 {get}
    var operationCode: OperationCode {get}
    
    func generateBsonMessage() throws -> [UInt8]
}

extension Message {
    internal func generateHeader(bodyLength: Int) throws -> [UInt8] {
        if bodyLength <= 0 {
            throw MongoError.InvalidBodyLength
        }
        
        var header = [UInt8]()
        header += Int32(16 + bodyLength).bsonData
        header += requestID.bsonData
        header += responseTo.bsonData
        header += operationCode.rawValue.bsonData
        
        return header
    }
}