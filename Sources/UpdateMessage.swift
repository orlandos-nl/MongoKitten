//
//  InsertMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public struct UpdateFlags : OptionSetType {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }
    
    public static let Upsert = UpdateFlags(rawValue: 1 << 0)
    public static let MultiUpdate = UpdateFlags(rawValue: 1 << 1)
}

internal struct UpdateMessage : Message {
    internal let collection: Collection
    
    internal let requestID: Int32
    internal let responseTo: Int32 = 0
    internal let operationCode = OperationCode.Update
    internal let findDocument: Document
    internal let replaceDocument: Document
    internal let flags: Int32
    
    internal func generateBsonMessage() throws -> [UInt8] {
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
    
    internal init(collection: Collection, find: Document, replace: Document, flags: UpdateFlags) throws {
        self.collection = collection
        self.findDocument = find
        self.replaceDocument = replace
        self.requestID = collection.database.server.getNextMessageID()
        self.flags = flags.rawValue
    }
}