//
//  InsertMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public struct InsertMessage : Message {
    public let collection: Collection
    
    public let requestID: Int32
    public let responseTo: Int32 = 0
    public let operationCode = OperationCode.Insert
    public let documents: [Document]
    public let flags: Int32
    
    public struct Flags : OptionSetType {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }
        
        public static let ContinueOnError = Flags(rawValue: 1 << 0)
    }
    
    public func generateBsonMessage() throws -> [UInt8] {
        var body = [UInt8]()
        
        body += flags.bsonData
        body += collection.fullName.cStringBsonData
        
        for document in documents {
            body += document.bsonData
        }
        
        var header = try generateHeader(body.count)
        header += body
        
        return header
    }
    
    public init(collection: Collection, insertedDocuments: [Document], flags: Flags) throws {
        guard let database: Database = collection.database else {
            throw MongoError.BrokenCollectionObject
        }
        
        self.collection = collection
        self.documents = insertedDocuments
        self.requestID = database.server.getNextMessageID()
        self.flags = flags.rawValue
    }
}