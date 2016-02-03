//
//  InsertMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 01/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public struct DeleteMessage : Message {
    public let collection: Collection
    
    public let requestID: Int32
    public let responseTo: Int32 = 0
    public let operationCode = OperationCode.Delete
    public let removeDocument: Document
    public let flags: Int32
    
    public struct Flags : OptionSetType {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }
        
        public static let RemoveOne = Flags(rawValue: 1 << 0)
    }
    
    public func generateBsonMessage() throws -> [UInt8] {
        var body = [UInt8]()
        
        body += Int32(0).bsonData
        body += collection.fullName.cStringBsonData
        
        body += flags.bsonData
        body += removeDocument.bsonData
        
        var header = try generateHeader(body.count)
        header += body
        
        return header
    }
    
    public init(collection: Collection, query: Document, flags: Flags) throws {
        guard let database: Database = collection.database else {
            throw MongoError.BrokenCollectionObject
        }
        
        self.collection = collection
        self.removeDocument = query
        self.requestID = database.server.getNextMessageID()
        self.flags = flags.rawValue
    }
}