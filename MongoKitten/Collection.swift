//
//  Collection.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 27/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public class Collection {
    let database: Database?
    let name: String
    var fullName: String {
        guard let dbname: String = database?.name else {
            return ""
        }
        
        return "\(dbname).\(name)"
    }
    
    public init(database: Database, collectionName: String) throws {
        let collectionName = collectionName.stringByReplacingOccurrencesOfString(".", withString: "")
        
        self.database = database
        
        if collectionName.characters.count < 1 {
            self.name = ""
            throw MongoError.InvalidCollectionName
        }
        
        self.name = collectionName
    }
    
    public init(server: Server, fullCollectionName name: String) throws {
        if !name.containsString(".") {
            self.database = nil
            self.name = ""
            throw MongoError.InvalidFullCollectionName
        }
        
        let splittedString = name.characters.split{$0 == "."}.map(String.init)
        
        if splittedString.count != 2 {
            self.database = nil
            self.name = ""
            throw MongoError.InvalidFullCollectionName
        }
        
        if splittedString[0].characters.count <= 0 && splittedString[1].characters.count <= 0 {
            self.database = nil
            self.name = ""
            throw MongoError.InvalidFullCollectionName
        }
        
        self.name = splittedString[1]
        self.database = server[splittedString[0]]
    }
    
    // CRUD Operations
    
    // Create
    
    public func insert(document: Document) throws {
        try insertAll([document])
    }
    
    public func insert(documents: [Document]) throws {
        try insertAll(documents)
    }
    
    public func insertAll(documents: [Document], flags: InsertMessage.Flags = []) throws {
        guard let database: Database = database else {
            throw MongoError.BrokenCollectionObject
        }
        
        if name.characters.count < 1 {
            throw MongoError.BrokenCollectionObject
        }
        
        let message = try InsertMessage(collection: self, insertedDocuments: documents, flags: flags)
        
        try database.server.sendMessage(message)
    }
    
    // Read
    
    public func find() throws {
        
    }
    
    public func findOne() throws {
        
    }
    
    public func findAll() throws {
        
    }
    
    // Update
    
    public func update(from: Document, to: Document, flags: UpdateMessage.Flags = []) throws {
        guard let database: Database = database else {
            throw MongoError.BrokenCollectionObject
        }
        
        if name.characters.count < 1 {
            throw MongoError.BrokenCollectionObject
        }
        
        let message = try UpdateMessage(collection: self, find: from, replace: to, flags: flags)
        
        try database.server.sendMessage(message)
    }
    
    public func upsert(from: Document, to: Document) throws {
        try update(from, to: to, flags: [.Upsert])
    }
    
    public func updateAll(from: Document, to: Document) throws {
        try update(from, to: to, flags: [.MultiUpdate])
    }
    
    // Delete
    
    public func remove(document: Document, flags: DeleteMessage.Flags = []) throws {
        guard let database: Database = database else {
            throw MongoError.BrokenCollectionObject
        }
        
        if name.characters.count < 1 {
            throw MongoError.BrokenCollectionObject
        }
        
        let message = try DeleteMessage(collection: self, query: document, flags: flags)
        
        try database.server.sendMessage(message)
    }
    
    public func removeOne(document: Document) throws {
        try remove(document, flags: [.RemoveOne])
    }
    
    public func removeAll(document: Document) throws {
        try remove(document)
    }
    // TODO: Implement subscript assignment for "update"
}