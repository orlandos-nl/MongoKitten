//
//  InsertMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

/// The flags that can be used in an Insert Message
public struct InsertFlags : OptionSetType {
    /// The raw value in Int32
    public let rawValue: Int32
    
    /// You can initialize this with an Int32 and compare the number with an array of InsertFlags
    public init(rawValue: Int32) { self.rawValue = rawValue }
    
    /// Continue inserting documents if one of them fails
    internal static let ContinueOnError = InsertFlags(rawValue: 1 << 0)
}

/// A message that can be sent to the Mongo Server that can convert itself to binary
internal struct InsertMessage : Message {
    /// The collection the documents specified underneath will be inserted to
    internal let collection: Collection
    
    /// The request's ID that can be replied to
    /// Hint: Insert Messages never get replies
    internal let requestID: Int32
    
    /// The requestID of the message this insert message responds to
    /// Always 0 because we're not responding unlike OP_REPLY
    internal let responseTo: Int32 = 0
    
    /// Our operation code. This is the Insert OPCode.. obviously
    internal let operationCode = OperationCode.Insert
    
    /// The documents we're inserting
    internal let documents: [Document]
    
    /// The flags that are given to us as Int32. This is equal to the rawValue of the given InsertFlags
    internal let flags: Int32
    
    /// Initializes this message with the given query and other information
    /// This message can be used internally to convert to binary ([UInt8]) which can be sent over the socket
    /// - returns: The binary ([Uint8]) variant of this message
    internal func generateBsonMessage() throws -> [UInt8] {
        var body = [UInt8]()
        
        body += flags.bsonData
        body += collection.fullName.cStringBsonData
        
        for document in documents {
            body += document.bsonData
        }
        
        let header = try generateHeader(body.count)
        let message = header + body
        
        return message
    }
    
    /// Initializes this message with the given documents
    /// - parameter collection: The collection the documents will be inserted to
    /// - parameter insertedDocuments: The list of documents that will be inserted.
    /// - parameter flags: The flags that are being used in this request. See InsertFlags for more details.
    internal init(collection: Collection, insertedDocuments: [Document], flags: InsertFlags) {
        self.collection = collection
        self.documents = insertedDocuments
        self.requestID = collection.database.server.getNextMessageID()
        self.flags = flags.rawValue
    }
}