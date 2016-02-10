//
//  InsertMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public struct InsertFlags : OptionSetType {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }
    
    internal static let ContinueOnError = InsertFlags(rawValue: 1 << 0)
}

internal struct InsertMessage : Message {
    internal let collection: Collection
    
    internal let requestID: Int32
    internal let responseTo: Int32 = 0
    internal let operationCode = OperationCode.Insert
    internal let documents: [Document]
    internal let flags: Int32
    
    internal func generateBsonMessage() throws -> [UInt8] {
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
    
    internal init(collection: Collection, insertedDocuments: [Document], flags: InsertFlags) {
        self.collection = collection
        self.documents = insertedDocuments
        self.requestID = collection.database.server.getNextMessageID()
        self.flags = flags.rawValue
    }
}