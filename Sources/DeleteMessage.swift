//
//  InsertMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 01/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

/// The flags that can be used in a Delete Message
public struct DeleteFlags : OptionSetType {
    /// The raw value in Int32
    public let rawValue: Int32
    
    /// You can initialize this with an Int32 and compare the number with an array of InsertFlags
    public init(rawValue: Int32) { self.rawValue = rawValue }
    
    /// Remove only the first matching Document from the collection
    public static let RemoveOne = DeleteFlags(rawValue: 1 << 0)
}

/// A message that can be sent to the Mongo Server that can convert itself to binary
internal struct DeleteMessage : Message {
    /// The colleciton the documents matching the query underneath will be removed from
    internal let collection: Collection
    
    /// The request's ID that can be replied to.
    /// Hint: Delete Messages never get replies
    internal let requestID: Int32
    
    /// The Request we're responding to. We're not responding at all so it's 0
    internal let responseTo: Int32 = 0
    
    /// Our message's OPCode. Obviously Delete
    internal let operationCode = OperationCode.Delete
    
    /// The selector document that we're using to match documents against.
    internal let removeDocument: Document
    
    /// The flags that are used with this message. See RemoveFlags for more details
    internal let flags: Int32
    
    /// Initializes this message with the given query and other information
    /// This message can be used internally to convert to binary ([UInt8]) which can be sent over the socket
    /// - returns: The binary ([Uint8]) variant of this message
    internal func generateBsonMessage() throws -> [UInt8] {
        var body = [UInt8]()
        
        body += Int32(0).bsonData
        body += collection.fullName.cStringBsonData
        
        body += flags.bsonData
        body += removeDocument.bsonData
        
        let header = try generateHeader(body.count)
        let message = header + body
        
        return message
    }
    
    /// Initializes this message with the given documents
    /// - parameter collection: The collection the documents will be removed from
    /// - parameter query: The selector that's used to find the Documents in the collection to be removed.
    /// - parameter flags: The flags that are being used in this request. See DeleteFlags for more details.
    internal init(collection: Collection, query: Document, flags: DeleteFlags) {
        self.collection = collection
        self.removeDocument = query
        self.requestID = collection.database.server.getNextMessageID()
        self.flags = flags.rawValue
    }
}