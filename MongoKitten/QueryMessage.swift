//
//  QueryMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 02/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public struct QueryMessage : Message {
    public let collection: Collection
    
    public let requestID: Int32
    public let numbersToSkip: Int32
    public let numbersToReturn: Int32
    public let responseTo: Int32 = 0
    public let operationCode = OperationCode.Query
    public let query: Document
    public let returnFields: Document?
    public let flags: Int32
    
    public struct Flags : OptionSetType {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }
        
        public static let TailableCursor = Flags(rawValue: 1 << 0)
        public static let NoCursorTimeout = Flags(rawValue: 4 << 0)
        public static let AwaitData = Flags(rawValue: 5 << 0)
        public static let Exhaust = Flags(rawValue: 6 << 0)
    }
    
    public func generateBsonMessage() throws -> [UInt8] {
        var body = [UInt8]()
        
        // Yes. Flags before collection. Consistent eh?
        body += flags.bsonData
        body += collection.fullName.cStringBsonData
        body += numbersToSkip.bsonData
        body += numbersToReturn.bsonData
        
        body += query.bsonData
        
        if let returnFields: Document = returnFields {
            body += returnFields.bsonData
        }
        
        var header = try generateHeader(body.count)
        header += body
        
        return header
    }
    
    public init(collection: Collection, query: Document, flags: Flags, numbersToSkip: Int32 = 0, numbersToReturn: Int32 = 0, returnFields: Document? = nil) throws {
        guard let database: Database = collection.database else {
            throw MongoError.BrokenCollectionObject
        }
        
        self.requestID = database.server.getNextMessageID()
        self.collection = collection
        self.query = query
        self.numbersToSkip = numbersToSkip
        self.numbersToReturn = numbersToReturn
        self.flags = flags.rawValue
        self.returnFields = returnFields
    }
}