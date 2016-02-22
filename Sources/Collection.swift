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

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// This file contains the low level code. This code is synchronous and is used by the async client API. //
//////////////////////////////////////////////////////////////////////////////////////////////////////////

/// A Mongo Collection. Cannot be publically initialized. But you can get a collection object by subscripting a Database with a String
public class Collection {
    /// The Database this collection is in
    public let database: Database
    
    /// The collection name
    public let name: String
    
    /// The full (computed) collection name. Created by adding the Database's name with the Collection's name with a dot to seperate them
    /// Will be empty
    public var fullName: String {
        return "\(database.name).\(name)"
    }
    
    /// Initializes this collection with a database and name
    /// All dots in the name will be removed
    internal init(database: Database, collectionName: String) {
        let collectionName = collectionName.stringByReplacingOccurrencesOfString(".", withString: "")
        
        self.database = database
        self.name = collectionName
    }
    
    // CRUD Operations
    
    // Create
    
    /// Insert a single document in this collection and adds a BSON ObjectId if none is present
    /// - parameter document: The BSON Document to be inserted
    /// - parameter flags: An optional list of InsertFlags that will be used with this Insert Operation
    /// - returns: The inserted document. The document will have a value for the "_id"-field.
    public func insertSync(document: Document, flags: InsertFlags = []) throws -> Document {
        // Create and return a future that executes the closure asynchronously
        // Use the insertAll to insert this single document
        let result = try self.insertAllSync([document], flags: flags)
        
        guard let newDocument: Document = result.first else {
            throw MongoError.InsertFailure(documents: [document])
        }
        
        return newDocument
    }
    
    /// Inserts all given document in this collection and adds a BSON ObjectId if none is present
    /// - parameter document: The BSON Documents to be inserted
    /// - parameter flags: An optional list of InsertFlags that will be used with this Insert Operation. See InsertFlags for more details
    /// - returns: An array with copies of the inserted documents. If the documents had no "_id" field when they were inserted, it is added in the returned documents.
    public func insertAllSync(documents: [Document], flags: InsertFlags = []) throws -> [Document] {
        let newDocuments = documents.map({ (input: Document) -> Document in
            if input["_id"] == nil {
                var output = input
                output["_id"] = ObjectId()
                return output
            } else {
                return input
            }
        })
        
        let message = InsertMessage(collection: self, insertedDocuments: newDocuments, flags: flags)
        try self.database.server.sendMessageSync(message)
        
        return newDocuments
    }
    
    // Read
    
    /// Looks for all Documents matching the query and returns them
    /// - parameter query: An optional BSON Document that will be used as a selector. All Documents in the response will match at least this Query's fields. By default all collection information will be selected
    /// - parameter flags: An optional list of QueryFlags that will be used with this Find/Query Operation. See InsertFlags for more details
    /// - parameter numbersToSkip: An optional integer that will tell MongoDB not to include the first X results in the found Documents
    /// - parameter numbersToReturn: Optional integer that will tell MongoDB to return the first X results that are not skipped.
    /// TODO: Above doc is out of date
    /// - returns: An array with zero or more found documents.
    @warn_unused_result
    public func find(query: Document = [], flags: QueryFlags = [], fetchChunkSize: Int32 = 10) throws -> Cursor {
        let queryMsg = try QueryMessage(collection: self, query: query, flags: [], numbersToSkip: 0, numbersToReturn: fetchChunkSize)
        
        let id = try self.database.server.sendMessageSync(queryMsg)
        let response = try self.database.server.awaitResponse(id)
        return Cursor(collection: self, reply: response, chunkSize: fetchChunkSize)
    }
    
    /// Looks for one Document matching the query and returns it in the Future
    /// - parameter query: An optional BSON Document that will be used as a selector. All Documents in the response will match at least this Query's fields. By default all collection information will be selected
    /// - parameter flags: An optional list of QueryFlags that will be used with this Find/Query Operation. See QueryFlags for more details
    /// - parameter numbersToSkip: An optional integer that will tell MongoDB not to use the first X results in the found Document
    /// - returns: Returns a future that you can await or asynchronously bind an action to. If you don't catch the error your application will crash. The future will return the first Document matching the given parameters or nil if none are found
//    public func findOne(query: Document, flags: QueryFlags = [], numbersToSkip: Int32 = 0) -> ThrowingFuture<Document?> {
//        let completer = ThrowingCompleter<Document?>()
//        
//        let documentsFuture = find(query, flags: flags, numbersToSkip: numbersToSkip, numbersToReturn: 1)
//        
//        documentsFuture.then { documents in
//            completer.complete(documents.first)
//        }
//        
//        return completer.future
//    }
    
    // Update
    
    /// Updates all Documents matching the query with the updated information using the flags
    /// - parameter query: The selector that will select all matching Documents (like find does) that will be selected for updating
    /// - parameter updated: The information that will be updated/added
    /// - parameter flags: The flags that will be used for this UpdateOperation. See UpdateFlags for more details
    /// - returns: Returns a future that you can await or asynchronously bind an action to. If you don't catch the error your application will crash. The future will return all changed Documents before they were changed
//    public func update(query: Document, updated: Document, flags: UpdateFlags = []) -> ThrowingFuture<[Document]> {
//        return ThrowingFuture<[Document]> {
//            let oldDocuments: [Document]
//            
//            if flags.contains([.MultiUpdate]) {
//                oldDocuments = try !>self.find(query)
//            } else if let oldDocument = try !>self.findOne(query) {
//                oldDocuments = [oldDocument]
//            } else {
//                return []
//            }
//            
//            let message = try UpdateMessage(collection: self, find: query, replace: updated, flags: flags)
//            
//            try self.database.server.sendMessage(message)
//            return oldDocuments
//        }
//    }
    
    // Delete
    /// Will remove all Documents matching the query
    /// - parameter document: The Document selector that will be use dto find th Document that will be removed1
    /// - parameter flags: The flags that will be used for this UpdateOperation. See DeleteFlags for more details
    /// - returns: Returns a future that you can await or asynchronously bind an action to. If you don't catch the error your application will crash. The future will return the all Documents that were found and removed.
//    public func remove(query: Document, flags: DeleteFlags = []) -> ThrowingFuture<[Document]> {
//        return ThrowingFuture<[Document]> {
//            let oldDocuments = try !>self.find(query)
//            
//            let message = DeleteMessage(collection: self, query: query, flags: flags)
//            
//            try self.database.server.sendMessage(message)
//            
//            return oldDocuments
//        }
//    }
    
    /// Will remove the first Document matching the query
    /// - parameter document: The Document selector that will be use dto find th Document that will be removed
    /// - returns: Returns a future that you can await or asynchronously bind an action to. If you don't catch the error your application will crash. The future will return the Document if one was found and removed. If there were no removed documents this will reutrn nil
//    public func removeOne(document: Document) -> ThrowingFuture<Document?> {
//        let completer = ThrowingCompleter<Document?>()
//        
//        let documentsFuture = remove(document, flags: [.RemoveOne])
//        
//        documentsFuture.then { documents in
//            completer.complete(documents.first)
//        }
//        
//        return completer.future
//    }
    // TODO: Implement subscript assignment for "update"
}