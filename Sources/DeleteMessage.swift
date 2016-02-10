//
//  InsertMessage.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 01/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public struct DeleteFlags : OptionSetType {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }
    
    public static let RemoveOne = DeleteFlags(rawValue: 1 << 0)
}

internal struct DeleteMessage : Message {
    internal let collection: Collection
    
    internal let requestID: Int32
    internal let responseTo: Int32 = 0
    internal let operationCode = OperationCode.Delete
    internal let removeDocument: Document
    internal let flags: Int32
    
    internal func generateBsonMessage() throws -> [UInt8] {
        var body = [UInt8]()
        
        body += Int32(0).bsonData
        body += collection.fullName.cStringBsonData
        
        body += flags.bsonData
        body += removeDocument.bsonData
        
        var header = try generateHeader(body.count)
        header += body
        
        return header
    }
    
    internal init(collection: Collection, query: Document, flags: DeleteFlags) {
        self.collection = collection
        self.removeDocument = query
        self.requestID = collection.database.server.getNextMessageID()
        self.flags = flags.rawValue
    }
}