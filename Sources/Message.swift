//
//  Message.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

enum Message {
    var responseTo: Int32 {
        switch self {
        case .Reply(_, let responseTo, _, _, _, _, _):
            return responseTo
        default:
            return 0
        }
    }
    
    var requestID: Int32 {
        switch self {
        case .Reply(let requestIdentifier, _, _, _, _, _, _):
            return requestIdentifier
        case .Query(let requestIdentifier, _, _, _, _, _, _):
            return requestIdentifier
        case .GetMore(let requestIdentifier, _, _, _):
            return requestIdentifier
        case .KillCursors(let requestIdentifier, _):
            return requestIdentifier
        }
    }
    
    var operationCode: Int32 {
        switch self {
        case .Reply:
            return 1
        case .Query:
            return 2004
        case .GetMore:
            return 2005
        case .KillCursors:
            return 2007
        }
    }
    
    static func ReplyFromBSON(data: [UInt8]) throws -> Message {
        guard let length: Int32 = try Int32.instantiate(bsonData: data[0...3]*) else {
            throw DeserializationError.ParseError
        }
        
        if length != Int32(data.count) {
            throw DeserializationError.InvalidDocumentLength
        }
        
        let requestID = try Int32.instantiate(bsonData: data[4...7]*)
        let responseTo = try Int32.instantiate(bsonData: data[8...11]*)
        
        let flags = try Int32.instantiate(bsonData: data[16...19]*)
        let cursorID = try Int64.instantiate(bsonData: data[20...27]*)
        let startingFrom = try Int32.instantiate(bsonData: data[28...31]*)
        let numbersReturned = try Int32.instantiate(bsonData: data[32...35]*)
        let documents = try Document.instantiateAll(data[36..<data.endIndex]*)
        
        return Message.Reply(requestID: requestID, responseTo: responseTo, flags: ReplyFlags.init(rawValue: flags), cursorID: cursorID, startingFrom: startingFrom, numbersReturned: numbersReturned, documents: documents)
    }
    
    func generateBsonMessage() throws -> [UInt8] {
        var body = [UInt8]()
        var requestID: Int32
        
        switch self {
        case .Reply:
            throw MongoError.InvalidAction
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
            body += namespace.cStringBsonData
            body += numberToReturn.bsonData
            body += cursorID.bsonData
            
            requestID = requestIdentifier
        case .KillCursors(let requestIdentifier, let cursorIDs):
            body += Int32(0).bsonData
            body += cursorIDs.map { $0.bsonData }.reduce([]) { $0 + $1 }
            
            requestID = requestIdentifier
        }
        
        // Generate the header using the variables in the protocol
        var header = [UInt8]()
        header += Int32(16 + body.count).bsonData
        header += requestID.bsonData
        header += responseTo.bsonData
        header += operationCode.bsonData
        
        return header + body
    }
    
    case Reply(requestID: Int32, responseTo: Int32, flags: ReplyFlags, cursorID: Int64, startingFrom: Int32, numbersReturned: Int32, documents: [Document])
    case Query(requestID: Int32, flags: QueryFlags, collection: Collection, numbersToSkip: Int32, numbersToReturn: Int32, query: Document, returnFields: Document?)
    case GetMore(requestID: Int32, namespace: String, numberToReturn: Int32, cursor: Int64)
    case KillCursors(requestID: Int32, cursorIDs: [Int64])
}