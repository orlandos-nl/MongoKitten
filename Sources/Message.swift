//
//  Message.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation


/// Message is the base of all Mongo Messages
internal protocol Message {
    /// The requestID for this message
    var requestID: Int32 {get}
    
    /// Does this message respond to another message?
    /// Only used on ReplyMessage
    var responseTo: Int32 {get}
    
    /// The OPCode of this message as specified in the Wire Protocol Spec
    var operationCode: OperationCode {get}
    
    /// This generates the message in UInt8's so we can send it over the socket to the database server
    func generateBsonMessage() throws -> [UInt8]
}

extension Message {
    /// This function generates the header of a message given the body's length
    /// Returns the header in a byte-array
    internal final func generateHeader(bodyLength: Int) throws -> [UInt8] {
        // If the body is non-exitent we can't create a header
        if bodyLength <= 0 {
            throw MongoError.InvalidBodyLength
        }
        
        // Generate the header using the variables in the protocol
        var header = [UInt8]()
        header += Int32(16 + bodyLength).bsonData
        header += requestID.bsonData
        header += responseTo.bsonData
        header += operationCode.rawValue.bsonData
        
        return header
    }
}