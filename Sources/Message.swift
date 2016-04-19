//
//  Message.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public typealias Byte = UInt8

/// Message to be send or received to/from the server
enum Message {
    /// The MessageID this message is responding to
    /// Will always be 0 unless it's a `Reply` message
    /// - returns: The message ID we're responding to. Always `0` if this is not a reply message.
    var responseTo: Int32 {
        switch self {
        case .Reply(_, let responseTo, _, _, _, _, _):
            return responseTo
        default:
            return 0
        }
    }
    
    /// Returns the requestID for this message
    /// - returns: The requestID for this message
    var requestID: Int32 {
        switch self {
        case .Reply(let requestIdentifier, _, _, _, _, _, _):
            return requestIdentifier
        case .Update(let requestIdentifier, _, _, _, _):
            return requestIdentifier
        case .Insert(let requestIdentifier, _, _, _):
            return requestIdentifier
        case .Query(let requestIdentifier, _, _, _, _, _, _):
            return requestIdentifier
        case .GetMore(let requestIdentifier, _, _, _):
            return requestIdentifier
        case .Delete(let requestIdentifier, _, _, _):
            return requestIdentifier
        case .KillCursors(let requestIdentifier, _):
            return requestIdentifier
        }
    }
    
    /// Return the OperationCode for this message
    /// Some OPCodes aren't being used anymore since MongoDB only requires these 4 messages now
    /// - returns: The matching operation code for this message
    var operationCode: Int32 {
        switch self {
        case .Reply:
            return 1
        case .Update:
            return 2001
        case .Insert:
            return 2002
        case .Query:
            return 2004
        case .GetMore:
            return 2005
        case .Delete:
            return 2006
        case .KillCursors:
            return 2007
        }
    }
    
    /// Builds a `.Reply` object from Binary JSON
    /// - parameter from: The data to create a Reply-message from
    /// - returns: The reply instance
    static func makeReply(from data: [UInt8]) throws -> Message {
        // Get the message length
        guard let length: Int32 = try Int32.instantiate(bsonData: data[0...3]*) else {
            throw DeserializationError.ParseError
        }
        
        // Check the message length
        if length != Int32(data.count) {
            throw DeserializationError.InvalidDocumentLength
        }
        
        /// Get our variables from the message
        let requestID = try Int32.instantiate(bsonData: data[4...7]*)
        let responseTo = try Int32.instantiate(bsonData: data[8...11]*)
        
        let flags = try Int32.instantiate(bsonData: data[16...19]*)
        let cursorID = try Int64.instantiate(bsonData: data[20...27]*)
        let startingFrom = try Int32.instantiate(bsonData: data[28...31]*)
        let numbersReturned = try Int32.instantiate(bsonData: data[32...35]*)
        let documents = try Document.instantiateAll(fromData: data[36..<data.endIndex]*)
        
        // Return the constructed reply
        return Message.Reply(requestID: requestID, responseTo: responseTo, flags: ReplyFlags.init(rawValue: flags), cursorID: cursorID, startingFrom: startingFrom, numbersReturned: numbersReturned, documents: documents)
    }
    
    /// Generates BSON From a Message
    /// - returns: The data from this message
    func generateData() throws -> [Byte] {
        var body = [Byte]()
        var requestID: Int32
        
        // Generate the body
        switch self {
        case .Reply:
            throw MongoError.InvalidAction
        case .Update(let requestIdentifier, let collection, let flags, let findDocument, let replaceDocument):
            body += Int32(0).bsonData
            body += collection.fullName.cStringBsonData
            body += flags.rawValue.bsonData
            body += findDocument.bsonData
            body += replaceDocument.bsonData
            
            requestID = requestIdentifier
        case .Insert(let requestIdentifier, let flags, let collection, let documents):
            body += flags.rawValue.bsonData
            body += collection.fullName.cStringBsonData
            
            for document in documents {
                body += document.bsonData
            }
            
            requestID = requestIdentifier
        case .Query(let requestIdentifier, let flags, let collection, let numbersToSkip, let numbersToReturn, let query, let returnFields):
            body += flags.rawValue.bsonData
            body += collection.fullName.cStringBsonData
            body += numbersToSkip.bsonData
            body += numbersToReturn.bsonData
            
            body += query.bsonData
            
            if let returnFields = returnFields {
                body += returnFields.bsonData
            }
            
            requestID = requestIdentifier
        case .GetMore(let requestIdentifier, let namespace, let numberToReturn, let cursorID):
            body += Int32(0).bsonData

            /// TODO: Fix inconsistency `namespace`
            body += namespace.cStringBsonData
            body += numberToReturn.bsonData
            body += cursorID.bsonData
            
            requestID = requestIdentifier
        case .Delete(let requestIdentifier, let collection, let flags, let removeDocument):
            body += Int32(0).bsonData
            body += collection.fullName.cStringBsonData
            body += flags.rawValue.bsonData
            body += removeDocument.bsonData
            
            requestID = requestIdentifier
        case .KillCursors(let requestIdentifier, let cursorIDs):
            body += Int32(0).bsonData
            body += cursorIDs.map { $0.bsonData }.reduce([]) { $0 + $1 }
            
            requestID = requestIdentifier
        }
        
        // Generate the header using the body
        var header = [Byte]()
        header += Int32(16 + body.count).bsonData
        header += requestID.bsonData
        header += responseTo.bsonData
        header += operationCode.bsonData
        
        return header + body
    }
    
    /// The Reply message that we can receive from the server
    /// - parameter requestID: The Request ID that you can get from the server by calling `server.nextMessageID()`
    /// - parameter responseTo: The Client-side query/getmore that this message responds to
    /// - parameter flags: The flags that are given with this message
    /// - parameter cursorID: The cursor that can be used to fetch more information (if available)
    /// - parameter startingFrom: The position in this cursor to start
    /// - parameter numbersReturned: The amount of returned results in this reply
    /// - parameter documents: The documents that have been returned
    case Reply(requestID: Int32, responseTo: Int32, flags: ReplyFlags, cursorID: Int64, startingFrom: Int32, numbersReturned: Int32, documents: [Document])
    
    /// Updates data on the server using an older method
    /// - parameter requestID: The Request ID that you can get from the server by calling `server.nextMessageID()`
    /// - parameter collection: The collection we'll update information in
    /// - parameter flags: The flags to be sent with this message
    /// - parameter findDocument: The filter to use when finding documents to update
    /// - parameter replaceDocument: The Document to replace the results with
    case Update(requestID: Int32, collection: Collection, flags: UpdateFlags, findDocument: Document, replaceDocument: Document)

    /// Insert data into the server using an older method
    /// - parameter requestID: The Request ID that you can get from the server by calling `server.nextMessageID()`
    /// - parameter flags: The flags to be sent with this message
    /// - parameter collection: The collection to insert information in
    /// - parameter documents: The documents to insert in the collection
    case Insert(requestID: Int32, flags: InsertFlags, collection: Collection, documents: [Document])
    
    /// Used for CRUD operations on the server.
    /// - parameter requestID: The Request ID that you can get from the server by calling `server.nextMessageID()`
    /// - parameter flags: The flags to be sent with this message
    /// - parameter collection: The collection to query to
    /// - parameter numbersToSkip: How many results to skip before processing
    /// - parameter numberToReturn: The amount of results to return
    /// - parameter query: The query to execute. Can be a DBCommand.
    /// - parameter returnFields: The fields to return or to ignore
    case Query(requestID: Int32, flags: QueryFlags, collection: Collection, numbersToSkip: Int32, numbersToReturn: Int32, query: Document, returnFields: Document?)
    
    /// Get more data from the cursor's selected data
    /// - parameter requestID: The Request ID that you can get from the server by calling `server.nextMessageID()`
    /// - parameter namespace: The namespace to get more information from like `mydatabase.mycollection` or `mydatabase.mybucket.mycollection`
    /// - parameter numbersToReturn: The amount of results to return
    /// - parameter cursor: The ID of the cursor that we will fetch more information from
    case GetMore(requestID: Int32, namespace: String, numberToReturn: Int32, cursor: Int64)
    
    /// Delete data from the server using an older method
    /// - parameter requestID: The Request ID that you can get from the server by calling `server.nextMessageID()`
    /// - parameter collection: The Collection to delete information from
    case Delete(requestID: Int32, collection: Collection, flags: DeleteFlags, removeDocument: Document)
    
    /// The message we send when we don't need the selected information anymore
    /// - parameter requestID: The Request ID that you can get from the server by calling `server.nextMessageID()`
    /// - parameter cursorIDs: The list of IDs that refer to cursors that need to be killed
    case KillCursors(requestID: Int32, cursorIDs: [Int64])
}