//
//  InsertMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public struct UpdateMessage : Message {
    public let collection: Collection
    
    public let requestID: Int32
    public let responseTo: Int32 = 0
    public let operationCode = OperationCode.Update
    public let findDocument: Document
    public let replaceDocument: Document
    public let flags: Int32
    
    public struct Flags : OptionSetType {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }
        
        public static let Upsert = Flags(rawValue: 1 << 0)
        public static let MultiUpdate = Flags(rawValue: 1 << 1)
    }
    
    public func generateBsonMessage() throws -> [UInt8] {
        var body = [UInt8]()

        body += Int32(0).bsonData
        body += collection.fullName.cStringBsonData
        
        body += flags.bsonData
        body += findDocument.bsonData
        body += replaceDocument.bsonData
    
        
        var header = try generateHeader(body.count)
        header += body
        
        return header
    }
    
    public init(collection: Collection, find: Document, replace: Document, flags: Flags) throws {
        guard let database: Database = collection.database else {
            throw MongoError.BrokenCollectionObject
        }
        
        self.collection = collection
        self.findDocument = find
        self.replaceDocument = replace
        self.requestID = database.server.getNextMessageID()
        self.flags = flags.rawValue
    }
}