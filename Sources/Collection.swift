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
    
    // MARK: - CRUD Operations
    
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
    public func find(query: Document = [], flags: QueryFlags = [], fetchChunkSize: Int32 = 10) throws -> Cursor<Document> {
        let queryMsg = try QueryMessage(collection: self, query: query, flags: [], numbersToSkip: 0, numbersToReturn: fetchChunkSize)
        
        let id = try self.database.server.sendMessageSync(queryMsg)
        let response = try self.database.server.awaitResponse(id)
        return Cursor(namespace: self.fullName, server: database.server, reply: response, chunkSize: fetchChunkSize, transform: { $0 })
    }
    
    /// Looks for one Document matching the query and returns it
    /// - parameter query: An optional BSON Document that will be used as a selector. All Documents in the response will match at least this Query's fields. By default all collection information will be selected
    /// - parameter flags: An optional list of QueryFlags that will be used with this Find/Query Operation. See QueryFlags for more details
    /// - returns: The first document matching the query or nil if none found
    public func findOne(query: Document = [], flags: QueryFlags = []) throws -> Document? {
        return try self.find(query, flags: flags, fetchChunkSize: 1).generate().next()
    }
    
    // Update
    
    /// Updates all Documents matching the query with the updated information using the flags
    /// - parameter query: The selector that will select all matching Documents (like find does) that will be selected for updating
    /// - parameter updated: The information that will be updated/added
    /// - parameter flags: The flags that will be used for this UpdateOperation. See UpdateFlags for more details
    /// - returns: Returns a future that you can await or asynchronously bind an action to. If you don't catch the error your application will crash. The future will return all changed Documents before they were changed
    public func update(query: Document, updated: Document, flags: UpdateFlags = []) throws {
        let message = try UpdateMessage(collection: self, find: query, replace: updated, flags: flags)
        try self.database.server.sendMessageSync(message)
    }
    
    // Delete
    /// Will remove all Documents matching the query
    /// - parameter document: The Document selector that will be use dto find th Document that will be removed1
    /// - parameter flags: The flags that will be used for this UpdateOperation. See DeleteFlags for more details
    public func remove(query: Document, flags: DeleteFlags = []) throws {
        let message = DeleteMessage(collection: self, query: query, flags: flags)
        try self.database.server.sendMessageSync(message)
    }
    
    /// The drop command removes an entire collection from a database. This command also removes any indexes associated with the dropped collection.
    public func drop() throws {
        try self.database.executeCommand(["drop": self.name])
    }
}