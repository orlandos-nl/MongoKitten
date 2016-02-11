//
//  QueryMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 02/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

/// The flags that can be used in a Find/Query message
public struct QueryFlags : OptionSetType {
    /// The raw value in Int32
    public let rawValue: Int32
    
    /// You can initialize this with an Int32 and compare the number with an array of QueryFlags
    public init(rawValue: Int32) { self.rawValue = rawValue }
    
//    internal static let TailableCursor = QueryFlags(rawValue: 1 << 0)
//    internal static let NoCursorTimeout = QueryFlags(rawValue: 4 << 0)
//    internal static let AwaitData = QueryFlags(rawValue: 5 << 0)
//    internal static let Exhaust = QueryFlags(rawValue: 6 << 0)
}

/// A message that can be sent to the Mongo Server that can convert itself to binary
internal struct QueryMessage : Message {
    /// The collection we'll search in for the documents
    internal let collection: Collection
    
    /// The request ID of this message that can be replied to.
    /// We will get a reply on this message
    internal let requestID: Int32
    
    /// The amount of resulting (matching to our query) documents to skip before looking for documents to return
    internal let numbersToSkip: Int32
    
    /// The amount of documents to return after which we'll stop sending more results
    internal let numbersToReturn: Int32
    
    /// The message we're responding to. Since this isn't a ReplyMessage we're not responding at all
    internal let responseTo: Int32 = 0
    
    /// Which operation code this message uses. Query.. of course.
    internal let operationCode = OperationCode.Query
    
    /// The query (as BSON Document) that we're using as selector to match other documents against.
    /// All documents that match this the contents of this query are candidates to be returned
    internal let query: Document
    
    /// Which fields do we retrun. Is optional since we might not provide this information at all.
    /// Structured as Document with a key of the field-name and a value of 1 as Int
    internal let returnFields: Document?
    
    /// Which flags we're using in this query. Look at QueryFlags for more details
    /// Currently none of the flags are supported since we're not working with cursors -- yet.
    internal let flags: QueryFlags
    
    /// Generates a binary message from our variables
    /// - returns: The binary ([Uint8]) variant of this message
    internal func generateBsonMessage() throws -> [UInt8] {
        var body = [UInt8]()
        
        // Yes. Flags before collection. Consistent eh?
        body += flags.rawValue.bsonData
        body += collection.fullName.cStringBsonData
        body += numbersToSkip.bsonData
        body += numbersToReturn.bsonData
        
        body += query.bsonData
        
        if let returnFields = returnFields {
            body += returnFields.bsonData
        }
        
        let header = try generateHeader(body.count)
        let message = header + body
        
        return message
    }
    
    /// Initializes this message with the given query and other information
    /// This message can be used internally to convert to binary ([UInt8]) which can be sent over the socket
    /// - parameter collection: The collection to look in for resulting Documents
    /// - parameter query: The selector as Document that we'll use to match our results against. Results must at least have the matching key-values from the given query
    /// - parameter flags: The flags that we'll use here. For more information look at QueryFlags
    /// - parameter numbersToSkip: The amount of resulting (matching to our query) documents to skip before looking for documents to return
    /// - parameter numbersToReturn: The amount of documents to return after which we'll stop sending more results
    /// - parameter returnFields: Which fields do we retrun. Is optional since we might not provide this information at all. Structured as Document with a key of the field-name and a value of 1 as Int
    internal init(collection: Collection, query: Document, flags: QueryFlags, numbersToSkip: Int32 = 0, numbersToReturn: Int32 = 0, returnFields: Document? = nil) throws {
        self.requestID = collection.database.server.getNextMessageID()
        self.collection = collection
        self.query = query
        self.numbersToSkip = numbersToSkip
        self.numbersToReturn = numbersToReturn
        self.flags = flags
        self.returnFields = returnFields
    }
}