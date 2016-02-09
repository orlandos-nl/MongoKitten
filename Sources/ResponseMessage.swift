//
//  ResponseMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 02/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public struct ResponseMessage : Message {
    public let collection: Collection
    
    public let requestID: Int32
    public let cursorId: Int64
    public let responseTo: Int32
    public let startingFrom: Int32
    public let numberReturned: Int32
    public let operationCode = OperationCode.Reply
    public let documents: [Document]
    public let flags: Int32
    
    public func generateBsonMessage() throws -> [UInt8] {
        throw MongoError.InvalidAction
    }
    
    public struct Flags : OptionSetType {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }
        
        public static let CursorNotFound = Flags(rawValue: 0 << 0)
        public static let QueryFailure = Flags(rawValue: 1 << 0)
        public static let AwaitCapable = Flags(rawValue: 2 << 0)
    }
    
    public init(collection: Collection, data: [UInt8]) throws {
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
    
    static func getResponseIdFromResponse(data: [UInt8]) throws -> Int32 {
        guard let length: Int32 = try Int32.instantiate(bsonData: data[0...3]*) else {
            throw DeserializationError.ParseError
        }
        
        if length != Int32(data.count) {
            throw DeserializationError.InvalidDocumentLength
        }
        
        let responseTo = try Int32.instantiate(bsonData: data[8...11]*)
        
        let operationCode: Int32 = try Int32.instantiate(bsonData: data[12...15]*)
        
        if operationCode != OperationCode.Reply.rawValue {
            throw DeserializationError.InvalidOperation
        }
        
        return responseTo
    }
    
    public init(collection: Collection, requestID: Int32, responseTo: Int32, cursorId: Int64, startingFrom: Int32, numberReturned: Int32, documents: [Document], flags: Flags) throws {
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