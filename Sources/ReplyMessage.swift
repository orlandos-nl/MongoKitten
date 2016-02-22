//
//  ReplyMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 02/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

/// The flags that are used by the Reply message
internal struct ReplyFlags : OptionSetType {
    /// The raw value in Int32
    internal let rawValue: Int32
    
    /// You can initialize this with an Int32 and compare the number with an array of ReplyFlags
    internal init(rawValue: Int32) { self.rawValue = rawValue }
    
    /// The server could not find the cursor we tried to use
    internal static let CursorNotFound = InsertFlags(rawValue: 0 << 0)
    
    /// The query we entered failed
    internal static let QueryFailure = InsertFlags(rawValue: 1 << 0)
    
    /// The server is await-capable and thus supports the QueryFlag's AwaitData flag
    internal static let AwaitCapable = InsertFlags(rawValue: 3 << 0)
}

/// The reply that will only ever be sent from a server
internal struct ReplyMessage : Message {
    /// The request's identifier
    internal let requestID: Int32
    
    /// The cursor that this message left responding at.
    /// You can use this cursor to get more results if they are available.
    internal let cursorId: Int64
    
    /// The Query or OP_GET_MORE that this message replied to.
    /// This is used to find the corresponding Closure in Server.swift which will be executed with the documents that are supplied by this message
    internal let responseTo: Int32
    
    /// The document the above cursor is starting from
    internal let startingFrom: Int32
    
    /// The amount of Documents in the reply
    internal let numberReturned: Int32
    
    /// The OPCode for this message.. Which is obviously Reply
    internal let operationCode = OperationCode.Reply
    
    /// The documents that the server replied with as an answer to our request
    internal let documents: [Document]
    
    /// The flags that we make use of. See ReplyFlags for more info
    internal let flags: Int32
    
    /// Generate binary from this struct. We don't support this since we are NOT a server
    internal func generateBsonMessage() throws -> [UInt8] {
        throw MongoError.InvalidAction
    }
    
    /// Initialize with the collection and reply binary data
    /// - parameter data: The binary data that this message should consist of
    internal init(data: [UInt8]) throws {
        guard let length: Int32 = try Int32.instantiate(bsonData: data[0...3]*) else {
            throw DeserializationError.ParseError
        }
        
        if length != Int32(data.count) {
            throw DeserializationError.InvalidDocumentLength
        }
        
        self.requestID = try Int32.instantiate(bsonData: data[4...7]*)
        self.responseTo = try Int32.instantiate(bsonData: data[8...11]*)
        
        let operationCode: Int32 = try Int32.instantiate(bsonData: data[12...15]*)
        
        if operationCode != self.operationCode.rawValue {
            throw DeserializationError.InvalidOperation
        }
        
        self.flags = try Int32.instantiate(bsonData: data[16...19]*)
        self.cursorId = try Int64.instantiate(bsonData: data[20...27]*)
        self.startingFrom = try Int32.instantiate(bsonData: data[28...31]*)
        self.numberReturned = try Int32.instantiate(bsonData: data[32...35]*)
        self.documents = try Document.instantiateAll(data[36..<data.endIndex]*)
    }
}