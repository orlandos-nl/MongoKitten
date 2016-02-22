//
//  GetMoreMessage.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 22-02-16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation

internal struct GetMoreMessage : Message {
    /// The collection we'll search in for the documents
    let collection: Collection
    
    /// The request ID of this message that can be replied to.
    /// We will get a reply on this message
    let requestID: Int32
    
    /// The message we're responding to. Since this isn't a ReplyMessage we're not responding at all
    let responseTo: Int32 = 0
    
    /// The operation code this message uses.
    let operationCode = OperationCode.GetMore
    
    /// Yeah, whatever.
    let zero: Int32 = 0
    
    /// Number of documents to return
    let numberToReturn: Int32
    
    /// The cursor ID
    let cursorID: Int64
    
    /// Generates a binary message from our variables
    /// - returns: The binary ([Uint8]) variant of this message
    internal func generateBsonMessage() throws -> [UInt8] {
        var body = [UInt8]()
        
        body += zero.bsonData
        body += collection.fullName.cStringBsonData
        body += numberToReturn.bsonData
        body += cursorID.bsonData
        
        let header = try generateHeader(body.count)
        
        return header + body
    }
    
    internal init(collection: Collection, cursorID: Int64, numberToReturn: Int32 = 0) throws {
        self.requestID = collection.database.server.getNextMessageID()
        self.collection = collection
        self.numberToReturn = numberToReturn
        self.cursorID = cursorID
    }
}