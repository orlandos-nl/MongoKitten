//
//  Collection.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 27/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// This file contains the low level code. This code is synchronous and is used by the async client API. //
//////////////////////////////////////////////////////////////////////////////////////////////////////////

/// A Mongo Collection. Cannot be publically initialized. But you can get a collection object by subscripting a Database with a String
public class Collection {
    /// The Database this collection is in
    public private(set) var database: Database
    
    /// The collection name
    public private(set) var name: String
    
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
    public func insert(document: Document, ordered: Bool? = nil) throws -> Document {
        // Create and return a future that executes the closure asynchronously
        // Use the insert to insert this single document
        let result = try self.insert([document], ordered: ordered)
        
        guard let newDocument: Document = result.first else {
            throw MongoError.InsertFailure(documents: [document])
        }
        
        return newDocument
    }
    
    /// Inserts all given document in this collection and adds a BSON ObjectId if none is present
    /// - parameter document: The BSON Documents to be inserted
    /// - parameter flags: An optional list of InsertFlags that will be used with this Insert Operation. See InsertFlags for more details
    /// - returns: An array with copies of the inserted documents. If the documents had no "_id" field when they were inserted, it is added in the returned documents.
    public func insert(documents: [Document], ordered: Bool? = nil) throws -> [Document] {
        var documents = documents
        var newDocuments = [Document]()
        
        while !documents.isEmpty {
            var command: Document = ["insert": self.name]
            
            let commandDocuments = documents[0..<min(1000, documents.count)].map({ (input: Document) -> BSONElement in
                if input["_id"] == nil {
                    var output = input
                    output["_id"] = ObjectId()
                    newDocuments.append(output)
                    return output
                } else {
                    newDocuments.append(input)
                    return input
                }
            })
            
            documents.removeFirst(min(1000, documents.count))
            
            command["documents"] = Document(array: commandDocuments)
            
            if let ordered = ordered {
                command["ordered"] = ordered
            }
            
            try database.executeCommand(command)
        }
        
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
    public func query(query: Document = [], flags: QueryFlags = [], fetchChunkSize: Int32 = 10) throws -> Cursor<Document> {
        let queryMsg = Message.Query(requestID: database.server.getNextMessageID(), flags: flags, collection: self, numbersToSkip: 0, numbersToReturn: fetchChunkSize, query: query, returnFields: nil)
        
        let id = try self.database.server.sendMessage(queryMsg)
        let response = try self.database.server.awaitResponse(id)
        guard let cursor = Cursor(namespace: self.fullName, server: database.server, reply: response, chunkSize: fetchChunkSize, transform: { $0 }) else {
            throw MongoError.InternalInconsistency
        }
        
        return cursor
    }
    
    public func query(query: Query) throws -> Cursor<Document> {
        return try self.query(query.data)
    }
    
    /// Looks for one Document matching the query and returns it
    /// - parameter query: An optional BSON Document that will be used as a selector. All Documents in the response will match at least this Query's fields. By default all collection information will be selected
    /// - parameter flags: An optional list of QueryFlags that will be used with this Find/Query Operation. See QueryFlags for more details
    /// - returns: The first document matching the query or nil if none found
    public func queryOne(query: Document = [], flags: QueryFlags = []) throws -> Document? {
        return try self.query(query, flags: flags, fetchChunkSize: 1).generate().next()
    }
    
    public func queryOne(query: Query) throws -> Document? {
        return try self.queryOne(query.data)
    }
    
    
    @warn_unused_result
    public func find(filter: Document? = nil, sort: Document? = nil, projection: Document? = nil, skip: Int32? = nil, limit: Int32? = nil, batchSize: Int32 = 10) throws -> Cursor<Document> {
        
        var command: Document = ["find": self.name]
        
        if let filter = filter {
            command += ["filter": filter]
        }
        
        if let sort = sort {
            command += ["sort": sort]
        }
        
        if let projection = projection {
            command += ["projection": projection]
        }
        
        if let skip = skip {
            command += ["skip": skip]
        }
        
        if let limit = limit {
            command += ["limit": limit]
        }
        
        command += ["batchSize": 10]
        
        if let sort = sort {
            command += ["sort": sort]
        }
        
        let reply = try database.executeCommand(command)
        
        guard case .Reply(_, _, _, let cursorID, _, _, let documents) = reply else {
            throw MongoError.InternalInconsistency
        }
        
        guard let returnedElements = documents.first?["cursor"]?.documentValue?["firstBatch"]?.documentValue?.arrayValue else {
            throw MongoError.InternalInconsistency
        }
        
        var returnedDocuments = [Document]()
        
        for element in returnedElements {
            if let document: Document = element.documentValue {
                returnedDocuments.append(document)
            }
        }
        
        return Cursor(namespace: self.fullName, server: database.server, cursorID: cursorID, initialData: returnedDocuments, chunkSize: batchSize, transform: { $0 })
    }
    
    @warn_unused_result
    public func find(filter: Query, sort: Document? = nil, projection: Document? = nil, skip: Int32? = nil, limit: Int32? = nil, batchSize: Int32 = 0) throws -> Cursor<Document> {
        return try find(filter.data, sort: sort, projection: projection, skip: skip, limit: limit, batchSize: batchSize)
    }
    
    @warn_unused_result
    public func findOne(filter: Document? = nil, sort: Document? = nil, projection: Document? = nil, skip: Int32? = nil, batchSize: Int32 = 0) throws -> Document? {
        return try self.find(filter, sort: sort, projection: projection, skip: skip, limit:
        1, batchSize: batchSize).generate().next()
    }
    
    @warn_unused_result
    public func findOne(filter: Query, sort: Document? = nil, projection: Document? = nil, skip: Int32? = nil, batchSize: Int32 = 0) throws -> Document? {
        return try findOne(filter.data, sort: sort, projection: projection, skip: skip, batchSize: batchSize)
    }
    
    // Update
    
    
    public func update(updates: [(query: Document, update: Document, upsert: Bool, multi: Bool)], ordered: Bool? = nil) throws {
        var command: Document = ["update": self.name]
        var newUpdates = [BSONElement]()
        
        for u in updates {
            newUpdates.append(*[
                               "q": u.query,
                               "u": u.update,
                               "upsert": u.upsert,
                               "multi": u.multi
                               ])
        }
        
        command["updates"] = Document(array: newUpdates)
        
        if let ordered = ordered {
            command["ordered"] = ordered
        }
        
        let reply = try self.database.executeCommand(command)
    }
    
    public func update(query: Document, updated: Document, upsert: Bool = false, multi: Bool = false, ordered: Bool? = nil) throws {
        return try self.update([(query: query, update: updated, upsert: upsert, multi: multi)], ordered: ordered)
    }
    
    public func update(updates: [(query: Query, update: Query, upsert: Bool, multi: Bool)], ordered: Bool? = nil) throws {
        let newUpdates = updates.map { (query: $0.query.data, update: $0.update.data, upsert: $0.upsert, multi: $0.multi) }
        
        try self.update(newUpdates, ordered: ordered)
    }
    
    public func update(query: Query, updated: Query, upsert: Bool = false, multi: Bool = false, ordered: Bool? = nil) throws {
        return try self.update([(query: query.data, update: updated.data, upsert: upsert, multi: multi)], ordered: ordered)
    }
    
    // Delete
    public func remove(deletes: [(query: Document, limit: Int32)], ordered: Bool? = nil) throws {
        var command: Document = ["delete": self.name]
        var newDeletes = [BSONElement]()
        
        for d in deletes {
            newDeletes.append(*[
                                   "q": d.query,
                                   "limit": d.limit
                ])
        }
        
        command["updates"] = Document(array: newDeletes)
        
        if let ordered = ordered {
            command["ordered"] = ordered
        }
        
        let reply = try self.database.executeCommand(command)
    }
    
    public func remove(deletes: [(query: Query, limit: Int32)], ordered: Bool? = nil) throws {
        let newDeletes = deletes.map { (query: $0.query.data, limit: $0.limit) }
        
        try self.remove(newDeletes, ordered: ordered)
    }
    
    public func remove(query: Document, limit: Int32, ordered: Bool? = nil) throws {        try self.remove([(query: query, limit: limit)], ordered: ordered)
    }
    
    public func remove(query: Query, limit: Int32, ordered: Bool? = nil) throws {
        try self.remove([(query: query.data, limit: limit)], ordered: ordered)
    }
    
    /// The drop command removes an entire collection from a database. This command also removes any indexes associated with the dropped collection.
    public func drop() throws {
        try self.database.executeCommand(["drop": self.name])
    }
    
    /// Changes the name of an existing collection. This method supports renames within a single database only. To move the collection to a different database, use the `move` method on `Collection`.
    /// - parameter newName: The new name for this collection
    public func rename(newName: String) throws {
        try self.move(toDatabase: database, newName: newName)
    }
    
    /// Move this collection to another database. Can also rename the collection in one go.
    /// **Users must have access to the admin database to run this command.**
    /// - parameter toDatabase: The database to move this collection to
    /// - parameter newName: The new name for this collection
    public func move(toDatabase newDb: Database, newName: String? = nil, dropTarget: Bool? = nil) throws {
        // TODO: Fail if the target database exists.
        var command: Document = [
            "renameCollection": self.fullName,
            "to": "\(newDb.name).\(newName ?? self.name)"
        ]
        
        if let dropTarget = dropTarget { command["dropTarget"] = dropTarget }
        
        try self.database.server["admin"]!.executeCommand(command)
        
        self.database = newDb
        self.name = newName ?? name
    }
    
    public func count(query: Document? = nil, limit: Int32? = nil, skip: Int32? = nil) throws -> Int? {
        var command: Document = ["count": self.fullName]
        
        if let query = query {
            command["query"] = query
        }
        
        if let skip = skip {
            command["skip"] = skip
        }
        
        let reply = try self.database.executeCommand(command)
        
        guard case .Reply(_, _, _, _, _, _, let documents) = reply else {
            throw MongoError.InternalInconsistency
        }
        
        return documents.first?["n"]?.intValue
    }
    
    public func distinct(key: String, query: Document? = nil) throws -> [BSONElement]? {
        var command: Document = ["distinct": self.name, "key": key]
        
        if let query = query {
            command["query"] = query
        }
        
        let reply = try self.database.executeCommand(command)
        
        guard case .Reply(_, _, _, _, _, _, let documents) = reply else {
            throw MongoError.InternalInconsistency
        }
        
        return documents.first?["values"]?.documentValue?.arrayValue
    }
}