//
//  Collection.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 27/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON
import When

public class Collection {
    public let database: Database
    public let name: String
    public var fullName: String {
        guard let dbname: String = database.name else {
            return ""
        }
        
        return "\(dbname).\(name)"
    }
    
    internal init(database: Database, collectionName: String) {
        let collectionName = collectionName.stringByReplacingOccurrencesOfString(".", withString: "")
        
        self.database = database
        self.name = collectionName
    }
    
    // CRUD Operations
    
    // Create
    
    public func insert(document: Document, flags: InsertFlags = []) -> ThrowingFuture<Document> {
        return ThrowingFuture<Document> {
            var document = document
            
            if !document.keys.contains("_id") {
                document.updateValue(ObjectId(), forKey: "_id")
            }
            
            try !>self.insertAll([document], flags: flags)
            
            return document
        }
    }
    
    public func insertAll(documents: [Document], flags: InsertFlags = []) -> ThrowingFuture<[Document]> {
        return ThrowingFuture<[Document]> {
            var newDocuments = [Document]()
            newDocuments.reserveCapacity(documents.count)
            
            for var document in documents {
                if !document.keys.contains("_id") {
                    document.updateValue(ObjectId(), forKey: "_id")
                }
                
                newDocuments.append(document)
            }
            
            let message = InsertMessage(collection: self, insertedDocuments: newDocuments, flags: flags)
            if try self.database.server.sendMessage(message) == false {
                throw MongoError.InsertFailure(documents: documents)
            }
            
            return newDocuments
        }
    }
    
    // Read
    
    public func find(query: Document, flags: QueryFlags = [], numbersToSkip: Int32 = 0, numbersToReturn: Int32 = 0) -> ThrowingFuture<[Document]> {
        return ThrowingCompleter<[Document]> { completer in
            
            let queryMsg = try QueryMessage(collection: self, query: query, flags: [], numbersToSkip: numbersToSkip, numbersToReturn: numbersToReturn)
            
            let result = try self.database.server.sendMessage(queryMsg) { reply in
                completer.complete(reply.documents)
            }
            
            if !result {
                throw MongoError.QueryFailure(query: query)
            }
        }.future
    }
    
    public func findOne(query: Document, flags: QueryFlags = [], numbersToSkip: Int32 = 0) -> ThrowingFuture<Document?> {
        let completer = ThrowingCompleter<Document?>()
        
        let documentsFuture = find(query, flags: flags, numbersToSkip: numbersToSkip)
        
        documentsFuture.then { documents in
            completer.complete(documents.first)
        }
        
        return completer.future
    }
    
    // Update
    
    public func update(query: Document, updated: Document, flags: UpdateFlags = []) -> ThrowingFuture<[Document]> {
        return ThrowingFuture<[Document]> {
            let oldDocuments = try !>self.find(query)
            
            let message = try UpdateMessage(collection: self, find: query, replace: updated, flags: flags)
            
            if try self.database.server.sendMessage(message) == false {
                throw MongoError.UpdateFailure(from: query, to: updated)
            }
            
            return oldDocuments
        }
    }
    
    // Delete
    
    public func remove(query: Document, flags: DeleteFlags = []) -> ThrowingFuture<[Document]> {
        return ThrowingFuture<[Document]> {
            let oldDocuments = try !>self.find(query)
            
            let message = DeleteMessage(collection: self, query: query, flags: flags)
            
            guard let works: Bool = try self.database.server.sendMessage(message) where works else {
                throw MongoError.RemoveFailure(query: query)
            }
            
            return oldDocuments
        }
    }
    
    public func removeOne(document: Document) -> ThrowingFuture<[Document]> {
        return remove(document, flags: [.RemoveOne])
    }
    // TODO: Implement subscript assignment for "update"
}