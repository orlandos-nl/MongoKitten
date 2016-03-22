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
    /// - returns: The inserted document. The document will have a value for the "_id"-field.
    @warn_unused_result
    public func insert(document: Document) throws -> Document {
        let result = try self.insert([document])
        
        guard let newDocument: Document = result.first else {
            throw MongoError.InsertFailure(documents: [document])
        }
        
        return newDocument
    }
    
    /// Inserts multiple documents in this collection and adds a BSON ObjectId to documents that do not have an "_id" field
    /// - parameter documents: The BSON Documents that should be inserted
    /// - parameter ordered: On true we'll stop inserting when one document fails. On false we'll ignore failed inserts
    /// - returns: The documents with their (if applicable) updated ObjectIds
    @warn_unused_result
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
            
            guard case .Reply(_, _, _, _, _, _, let replyDocuments) = try self.database.executeCommand(command) where replyDocuments.first?["ok"]?.int32Value == 1 else {
                throw MongoError.InsertFailure(documents: documents)
            }
        }
        
        return newDocuments
    }
    
    // Read
    
    /// Queries this collection with a Document
    /// Can be used for DBCommands as well as find commands.
    /// For MongoDB server 3.2 and higher we'd recommend using the `find` method in this Collection for security.
    /// - parameter query: The document that we're matching against in this collection
    /// - parameter flags: The Query Flags that we'll use for this query
    /// - parameter fetchChunkSize: The initial amount of returned Documents. We recommend at least one Document.
    /// - returns: A Cursor pointing to the response Documents.
    @warn_unused_result
    public func query(query: Document = [], flags: QueryFlags = [], fetchChunkSize: Int32 = 10) throws -> Cursor<Document> {
        let queryMsg = Message.Query(requestID: database.server.getNextMessageID(), flags: flags, collection: self, numbersToSkip: 0, numbersToReturn: fetchChunkSize, query: query, returnFields: nil)
        
        let id = try self.database.server.sendMessage(queryMsg)
        let response = try self.database.server.awaitResponse(id)
        guard let cursor = Cursor(namespace: self.fullName, server: database.server, reply: response, chunkSize: fetchChunkSize, transform: { $0 }) else {
            throw MongoError.InvalidReply
        }
        
        return cursor
    }
    
    
    /// Queries this collection with a Document (which comes from the Query)
    /// Can be used for DBCommands as well as find commands.
    /// For MongoDB server 3.2 and higher we'd recommend using the `find` method in this Collection for security.
    /// - parameter query: The Query that we're matching against in this collection. This query is from the MongoKitten QueryBuilder.
    /// - parameter flags: The Query Flags that we'll use for this query
    /// - parameter fetchChunkSize: The initial amount of returned Documents. We recommend at least one Document.
    /// - returns: A Cursor pointing to the response Documents.
    @warn_unused_result
    public func query(query: Query, flags: QueryFlags = [], fetchChunkSize: Int32 = 10) throws -> Cursor<Document> {
        return try self.query(query.data, flags: flags, fetchChunkSize: fetchChunkSize)
    }
    
    /// Queries this collection with a Document and returns the first result
    /// Can be used for DBCommands as well as find commands.
    /// For MongoDB server 3.2 and higher we'd recommend using the `find` method in this Collection for security.
    /// - parameter query: The document that we're matching against in this collection
    /// - parameter flags: The Query Flags that we'll use for this query
    /// - parameter fetchChunkSize: The initial amount of returned Documents. We recommend at least one Document.
    /// - returns: The first Document in the Response
    @warn_unused_result
    public func queryOne(query: Document = [], flags: QueryFlags = []) throws -> Document? {
        return try self.query(query, flags: flags, fetchChunkSize: 1).generate().next()
    }
    
    
    /// Queries this collection with a Document (which comes from the Query)
    /// Can be used for DBCommands as well as find commands.
    /// For MongoDB server 3.2 and higher we'd recommend using the `find` method in this Collection for security.
    /// - parameter query: The Query that we're matching against in this collection. This query is from the MongoKitten QueryBuilder.
    /// - parameter flags: The Query Flags that we'll use for this query
    /// - parameter fetchChunkSize: The initial amount of returned Documents. We recommend at least one Document.
    /// - returns: The first Document in the Response
    @warn_unused_result
    public func queryOne(query: Query, flags: QueryFlags = []) throws -> Document? {
        return try self.queryOne(query.data, flags: flags)
    }
    
    /// Finds Documents in this collection
    /// Cannot be used for DBCommands when using MongoDB 3.2 or higher
    /// - parameter filter: The filter we're using to match Documents in this collection against
    /// - parameter sort: The Sort Specification used to sort the found Documents
    /// - parameter projection: The Projection Specification used to filter which fields to return
    /// - parameter skip: The amount of Documents to skip before returning the matching Documents
    /// - parameter limit: The maximum amount of matching documents to return
    /// - parameter batchSize: The initial amount of Documents to return.
    /// - returns: A cursor pointing to the found Documents
    @warn_unused_result
    public func find(filter: Document? = nil, sort: Document? = nil, projection: Document? = nil, skip: Int32? = nil, limit: Int32? = nil, batchSize: Int32 = 10) throws -> Cursor<Document> {
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        
        switch protocolVersion {
        case 4:
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
            
            command += ["batchSize": Int32(10)]
            
            if let sort = sort {
                command += ["sort": sort]
            }
            
            let reply = try database.executeCommand(command)
            
            guard case .Reply(_, _, _, let cursorID, _, _, let documents) = reply else {
                throw InternalMongoError.IncorrectReply(reply: reply)
            }
            
            guard let returnedElements = documents.first?["cursor"]?.documentValue?["firstBatch"]?.documentValue?.arrayValue else {
                throw MongoError.InvalidResponse(documents: documents)
            }
            
            var returnedDocuments = [Document]()
            
            for element in returnedElements {
                if let document: Document = element.documentValue {
                    returnedDocuments.append(document)
                }
            }
            
            return Cursor(namespace: self.fullName, server: database.server, cursorID: cursorID, initialData: returnedDocuments, chunkSize: batchSize, transform: { $0 })
        default:
            let queryMsg = Message.Query(requestID: database.server.getNextMessageID(), flags: [], collection: self, numbersToSkip: skip ?? 0, numbersToReturn: batchSize, query: filter ?? [], returnFields: projection)
            
            let id = try self.database.server.sendMessage(queryMsg)
            let reply = try self.database.server.awaitResponse(id)
            
            guard case .Reply(_, _, _, let cursorID, _, _, let documents) = reply else {
                throw InternalMongoError.IncorrectReply(reply: reply)
            }
            
            return Cursor(namespace: self.fullName, server: database.server, cursorID: cursorID, initialData: documents, chunkSize: batchSize, transform: { $0 })
        }
    }
    
    /// Finds Documents in this collection
    /// Cannot be used for DBCommands when using MongoDB 3.2 or higher
    /// - parameter filter: The QueryBuilder filter we're using to match Documents in this collection against
    /// - parameter sort: The Sort Specification used to sort the found Documents
    /// - parameter projection: The Projection Specification used to filter which fields to return
    /// - parameter skip: The amount of Documents to skip before returning the matching Documents
    /// - parameter limit: The maximum amount of matching documents to return
    /// - parameter batchSize: The initial amount of Documents to return.
    /// - returns: A cursor pointing to the found Documents
    @warn_unused_result
    public func find(filter: Query, sort: Document? = nil, projection: Document? = nil, skip: Int32? = nil, limit: Int32? = nil, batchSize: Int32 = 0) throws -> Cursor<Document> {
        return try find(filter.data, sort: sort, projection: projection, skip: skip, limit: limit, batchSize: batchSize)
    }
    
    /// Finds Documents in this collection
    /// Cannot be used for DBCommands when using MongoDB 3.2 or higher
    /// - parameter filter: The Document filter we're using to match Documents in this collection against
    /// - parameter sort: The Sort Specification used to sort the found Documents
    /// - parameter projection: The Projection Specification used to filter which fields to return
    /// - parameter skip: The amount of Documents to skip before returning the matching Documents
    /// - returns: The found Document
    @warn_unused_result
    public func findOne(filter: Document? = nil, sort: Document? = nil, projection: Document? = nil, skip: Int32? = nil) throws -> Document? {
        return try self.find(filter, sort: sort, projection: projection, skip: skip, limit:
            1).generate().next()
    }
    
    /// Finds Documents in this collection
    /// Cannot be used for DBCommands when using MongoDB 3.2 or higher
    /// - parameter filter: The QueryBuilder filter we're using to match Documents in this collection against
    /// - parameter sort: The Sort Specification used to sort the found Documents
    /// - parameter projection: The Projection Specification used to filter which fields to return
    /// - parameter skip: The amount of Documents to skip before returning the matching Documents
    /// - returns: The found Document
    @warn_unused_result
    public func findOne(filter: Query, sort: Document? = nil, projection: Document? = nil, skip: Int32? = nil) throws -> Document? {
        return try findOne(filter.data, sort: sort, projection: projection, skip: skip)
    }
    
    // Update
    
    /// Updates a list of Documents using a counterpart Document.
    /// - parameter updates: A list of updates to be executed.
    ///     `query`: A filter to narrow down which Documents you want to update
    ///     `update`: The fields and values to update
    ///     `upsert`: If there isn't anything to update.. insert?
    ///     `multi`: Update all matching Documents instead of just one?
    /// - parameter ordered: If true, stop updating when one operation fails - defaults to true
    public func update(updates: [(query: Document, update: Document, upsert: Bool, multi: Bool)], ordered: Bool? = nil) throws {
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        
        switch protocolVersion {
        case 2...4:
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
        
        guard case .Reply(_, _, _, _, _, _, let documents) = try self.database.executeCommand(command) where documents.first?["ok"]?.int32Value == 1 else {
            throw MongoError.UpdateFailure(updates: updates)
        }
        default:
            for update in updates {
                var flags: UpdateFlags = []
                
                if update.multi {
                    flags.insert(UpdateFlags.MultiUpdate)
                }
                
                if update.upsert {
                    flags.insert(UpdateFlags.Upsert)
                }
                
                let message = Message.Update(requestID: database.server.getNextMessageID(), collection: self, flags: flags, findDocument: update.query, replaceDocument: update.update)
                try self.database.server.sendMessage(message)
            }
        }
    }
    
    /// Updates a Document with some new Keys and Values
    /// - parameter query: The filter to use when searching for Documents to update
    /// - parameter updated: The data to update these Documents with
    /// - parameter upsert: Insert when we can't find anything to update
    /// - parameter multi: Updates more than one result if true
    /// - parameter ordered: If true, stop updating when one operation fails - defaults to true
    public func update(query: Document, updated: Document, upsert: Bool = false, multi: Bool = false, ordered: Bool? = nil) throws {
        return try self.update([(query: query, update: updated, upsert: upsert, multi: multi)], ordered: ordered)
    }
    
    /// Updates a list of Documents using a counterpart Document.
    /// - parameter updates: A list of updates to be executed.
    ///     `query`: A QueryBuilder filter to narrow down which Documents you want to update
    ///     `update`: The fields and values to update
    ///     `upsert`: If there isn't anything to update.. insert?
    ///     `multi`: Update all matching Documents instead of just one?
    /// - parameter ordered: If true, stop updating when one operation fails - defaults to true
    public func update(updates: [(query: Query, update: Document, upsert: Bool, multi: Bool)], ordered: Bool? = nil) throws {
        let newUpdates = updates.map { (query: $0.query.data, update: $0.update, upsert: $0.upsert, multi: $0.multi) }
        
        try self.update(newUpdates, ordered: ordered)
    }
    
    /// Updates a Document with some new Keys and Values
    /// - parameter query: The QueryBuilder filter to use when searching for Documents to update
    /// - parameter updated: The data to update these Documents with
    /// - parameter upsert: Insert when we can't find anything to update
    /// - parameter multi: Updates more than one result if true
    /// - parameter ordered: If true, stop updating when one operation fails - defaults to true
    public func update(query: Query, updated: Document, upsert: Bool = false, multi: Bool = false, ordered: Bool? = nil) throws {
        return try self.update([(query: query.data, update: updated, upsert: upsert, multi: multi)], ordered: ordered)
    }
    
    // Delete
    
    /// Removes all Documents matching the filter if they're within limit
    /// - parameter removals: A list of filters to match documents against. Any given filter can be used infinite amount of removals if `0` or otherwise as often as specified in the limit
    /// - parameter ordered: If true, stop removing when one operation fails - defaults to true
    public func remove(removals: [(query: Document, limit: Int32)], ordered: Bool? = nil) throws {
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        
        switch protocolVersion {
        case 2...4:
        var command: Document = ["delete": self.name]
        var newDeletes = [BSONElement]()
        
        for d in removals {
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
        let documents = try database.documentsInMessage(reply)
        
        guard documents.first?["ok"]?.int32Value == 1 else {
            throw MongoError.RemoveFailure(removals: removals)
        }
            // If we're talking to an older MongoDB server
        default:
            for removal in removals {
                var flags: DeleteFlags = []
                
                // If the limit is 0, make the for loop run exactly once so the message sends
                // If the limit is not 0, set the limit properly
                let limit = removal.limit == 0 ? 1 : removal.limit
                
                // If the limit is not '0' and thus removes a set amount of documents. Set it to RemoveOne so we'll remove one document at a time using the older method
                if removal.limit != 0 {
                    flags.insert(DeleteFlags.RemoveOne)
                }
                
                let message = Message.Delete(requestID: database.server.getNextMessageID(), collection: self, flags: flags, removeDocument: removal.query)
                
                for _ in 0..<limit {
                    try self.database.server.sendMessage(message)
                }
            }
        }
    }
    
    /// Removes all Documents matching the filter if they're within limit
    /// - parameter removals: A list of QueryBuilder filters to match documents against. Any given filter can be used infinite amount of removals if `0` or otherwise as often as specified in the limit
    /// - parameter ordered: If true, stop removing when one operation fails - defaults to true
    public func remove(deletes: [(query: Query, limit: Int32)], ordered: Bool? = nil) throws {
        let newDeletes = deletes.map { (query: $0.query.data, limit: $0.limit) }
        
        try self.remove(newDeletes, ordered: ordered)
    }
    
    /// Removes all Documents matching the filter if they're within limit
    /// - parameter query: The Document filter to use when finding Documents that are going to be removed
    /// - parameter limit: The amount of times this filter can be used to find and remove a Document (0 is every document)
    /// - parameter ordered: If true, stop removing when one operation fails - defaults to true
    public func remove(query: Document, limit: Int32, ordered: Bool? = nil) throws {
        try self.remove([(query: query, limit: limit)], ordered: ordered)
    }
    
    /// Removes all Documents matching the filter if they're within limit
    /// - parameter query: The QueryBuilder filter to use when finding Documents that are going to be removed
    /// - parameter limit: The amount of times this filter can be used to find and remove a Document (0 is every document)
    /// - parameter ordered: If true, stop removing when one operation fails - defaults to true
    public func remove(query: Query, limit: Int32, ordered: Bool? = nil) throws {
        try self.remove([(query: query.data, limit: limit)], ordered: ordered)
    }
    
    /// The drop command removes an entire collection from a database. This command also removes any indexes associated with the dropped collection.
    public func drop() throws {
        _ = try self.database.executeCommand(["drop": self.name])
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
        
        _ = try self.database.server["admin"].executeCommand(command)
        
        self.database = newDb
        self.name = newName ?? name
    }
    
    /// Returns the amount of Documents in this collection
    /// - parameter query: Optional. If specified limits the returned amount to anything matching this query
    /// - parameter limit: Optional. Limits the returned amount as specified
    /// - parameter skip: Optional. The amount of Documents to skip before counting
    @warn_unused_result
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
            throw InternalMongoError.IncorrectReply(reply: reply)
        }
        
        return documents.first?["n"]?.intValue
    }
    
    @warn_unused_result
    public func distinct(key: String, query: Document? = nil) throws -> [BSONElement]? {
        var command: Document = ["distinct": self.name, "key": key]
        
        if let query = query {
            command["query"] = query
        }
        
        let reply = try self.database.executeCommand(command)
        
        guard case .Reply(_, _, _, _, _, _, let documents) = reply else {
            throw InternalMongoError.IncorrectReply(reply: reply)
        }
        
        return documents.first?["values"]?.documentValue?.arrayValue
    }
}