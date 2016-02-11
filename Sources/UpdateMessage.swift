//
//  InsertMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

/// The flags that can be used in an Update Message
public struct UpdateFlags : OptionSetType {
    /// The raw value in Int32
    public let rawValue: Int32
    
    /// You can initialize this with an Int32 and compare the number with an array of InsertFlags
    public init(rawValue: Int32) { self.rawValue = rawValue }
    
    /// If we can't find any resulting documents to update.. insert it
    public static let Upsert = UpdateFlags(rawValue: 1 << 0)
    
    /// Update more than one matching document
    public static let MultiUpdate = UpdateFlags(rawValue: 1 << 1)
}

/// A message that can be sent to the Mongo Server that can convert itself to binary
internal struct UpdateMessage : Message {
    /// The collection the documents are updated in
    internal let collection: Collection
    
    /// The request's ID that can be replied to
    /// Hint: Insert Messages never get replies
    internal let requestID: Int32
    
    /// The requestID of the message this insert message responds to
    /// Always 0 because we're not responding unlike OP_REPLY
    internal let responseTo: Int32 = 0
    
    /// Our operation code. This is the Update OPCode.. obviously
    internal let operationCode = OperationCode.Update
    
    /// The doument we're matching against. All documents in the collection that match against this Document are canditate for updating
    internal let findDocument: Document
    
    /// The values we'll replace and the keys the values belong to
    internal let replaceDocument: Document
    
    /// The flags that are given to us as Int32. This is equal to the rawValue of the given UpdateFlags
    internal let flags: Int32
    
    /// Initializes this message with the given query and other information
    /// This message can be used internally to convert to binary ([UInt8]) which can be sent over the socket
    /// - returns: The binary ([Uint8]) variant of this message
    internal func generateBsonMessage() throws -> [UInt8] {
        var body = [UInt8]()

        body += Int32(0).bsonData
        body += collection.fullName.cStringBsonData
        
        body += flags.bsonData
        body += findDocument.bsonData
        body += replaceDocument.bsonData
    
        let header = try generateHeader(body.count)
        let message = header + body
        
        return message
    }
    
    /// Initializes this message with the given Find and Replace/Update documents and flags
    /// - parameter collection: The collection the documents will be matched and updated in
    /// - parameter find: The selector Document that will be used to find matching Documents with for updating
    /// - parameter replace: The updated fields and their corresponding keys that will be updated
    /// - parameter flags: The flags that are being used in this request. See UpdateFlags for more details.
    internal init(collection: Collection, find: Document, replace: Document, flags: UpdateFlags) throws {
        self.collection = collection
        self.findDocument = find
        self.replaceDocument = replace
        self.requestID = collection.database.server.getNextMessageID()
        self.flags = flags.rawValue
    }
}