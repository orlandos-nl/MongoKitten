//
//  QueryMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 02/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public struct QueryFlags : OptionSetType {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }
    
    internal static let TailableCursor = QueryFlags(rawValue: 1 << 0)
    internal static let NoCursorTimeout = QueryFlags(rawValue: 4 << 0)
    internal static let AwaitData = QueryFlags(rawValue: 5 << 0)
    internal static let Exhaust = QueryFlags(rawValue: 6 << 0)
}

internal struct QueryMessage : Message {
    internal let collection: Collection
    
    internal let requestID: Int32
    internal let numbersToSkip: Int32
    internal let numbersToReturn: Int32
    internal let responseTo: Int32 = 0
    internal let operationCode = OperationCode.Query
    internal let query: Document
    internal let returnFields: Document?
    internal let flags: Int32
    
    internal func generateBsonMessage() throws -> [UInt8] {
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
    
    internal init(collection: Collection, query: Document, flags: QueryFlags, numbersToSkip: Int32 = 0, numbersToReturn: Int32 = 0, returnFields: Document? = nil) throws {
        self.requestID = collection.database.server.getNextMessageID()
        self.collection = collection
        self.query = query
        self.numbersToSkip = numbersToSkip
        self.numbersToReturn = numbersToReturn
        self.flags = flags.rawValue
        self.returnFields = returnFields
    }
}