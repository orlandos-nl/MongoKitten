//
//  ReplyMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 02/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

internal struct ReplyMessage : Message {
    internal let collection: Collection
    
    internal let requestID: Int32
    internal let cursorId: Int64
    internal let responseTo: Int32
    internal let startingFrom: Int32
    internal let numberReturned: Int32
    internal let operationCode = OperationCode.Reply
    internal let documents: [Document]
    internal let flags: Int32
    
    internal func generateBsonMessage() throws -> [UInt8] {
        throw MongoError.InvalidAction
    }
    
    internal struct Flags : OptionSetType {
        internal let rawValue: Int32
        internal init(rawValue: Int32) { self.rawValue = rawValue }
        
        internal static let CursorNotFound = Flags(rawValue: 0 << 0)
        internal static let QueryFailure = Flags(rawValue: 1 << 0)
        internal static let AwaitCapable = Flags(rawValue: 2 << 0)
    }
    
    internal init(collection: Collection, data: [UInt8]) throws {
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
        self.collection = collection
    }
    
    internal init(collection: Collection, requestID: Int32, responseTo: Int32, cursorId: Int64, startingFrom: Int32, numberReturned: Int32, documents: [Document], flags: Flags) throws {
        self.collection = collection
        self.responseTo = responseTo
        self.cursorId = cursorId
        self.requestID = requestID
        self.startingFrom = startingFrom
        self.numberReturned = numberReturned
        self.documents = documents
        self.flags = flags.rawValue
    }
}