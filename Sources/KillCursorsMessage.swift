//
//  KillCursorsMessage.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 22-02-16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation

internal struct KillCursorsMessage : Message {
    /// The request ID of this message that can be replied to.
    /// We will get a reply on this message
    let requestID: Int32
    
    /// The message we're responding to. Since this isn't a ReplyMessage we're not responding at all
    let responseTo: Int32 = 0
    
    /// The operation code this message uses.
    let operationCode = OperationCode.GetMore
    
    /// Yeah, whatever.
    let zero: Int32 = 0
    
    /// The cursor IDs to close
    let cursorIDs: [Int64]
    
    /// Generates a binary message from our variables
    /// - returns: The binary ([Uint8]) variant of this message
    internal func generateBsonMessage() throws -> [UInt8] {
        var body = [UInt8]()
        
        body += zero.bsonData
        body += Int32(cursorIDs.count).bsonData
        body += cursorIDs.map { $0.bsonData }.reduce([]) { $0 + $1 }
        
        let header = try generateHeader(body.count)
        
        return header + body
    }
    
    internal init(collection: Collection, cursorIDs: [Int64]) throws {
        self.requestID = collection.database.server.getNextMessageID()
        self.cursorIDs = cursorIDs
    }
}