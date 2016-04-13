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
    internal init(named name: String, in database: Database) {
        self.database = database
        self.name = name
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
    
    /// TODO: Detect how many bytes are being sent. Max is 48000000 bytes or 48MB
    /// Inserts multiple documents in this collection and adds a BSON ObjectId to documents that do not have an "_id" field
    /// - parameter documents: The BSON Documents that should be inserted
    /// - parameter ordered: On true we'll stop inserting when one document fails. On false we'll ignore failed inserts
    /// - parameter timeout: A custom timeout. The default timeout is 60 seconds + 1 second for every 50 documents, so when inserting 5000 documents at once, the timeout is 560 seconds.
    /// - returns: The documents with their (if applicable) updated ObjectIds
    @warn_unused_result
    public func insert(documents: [Document], stoppingOnError ordered: Bool? = nil, timeout customTimeout: NSTimeInterval? = nil) throws -> [Document] {
        let timeout: NSTimeInterval
        if let customTimeout = customTimeout {
            timeout = customTimeout
        } else {
            timeout = 60 + (Double(documents.count) / 50)
        }
        
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
            
            guard case .Reply(_, _, _, _, _, _, let replyDocuments) = try self.database.execute(command: command, until: timeout) where replyDocuments.first?["ok"]?.int32Value == 1 else {
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
    public func query(matching filter: Document = [], usingFlags flags: QueryFlags = [], fetching fetchChunkSize: Int32 = 10) throws -> Cursor<Document> {
        let queryMsg = Message.Query(requestID: database.server.nextMessageID(), flags: flags, collection: self, numbersToSkip: 0, numbersToReturn: fetchChunkSize, query: filter, returnFields: nil)
        
        let id = try self.database.server.send(message: queryMsg)
        let response = try self.database.server.await(response: id)
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
    public func query(matching filter: Query, usingFlags flags: QueryFlags = [], fetching fetchChunkSize: Int32 = 10) throws -> Cursor<Document> {
        return try self.query(matching: filter.data, usingFlags: flags, fetching: fetchChunkSize)
    }
    
    /// Queries this collection with a Document and returns the first result
    /// Can be used for DBCommands as well as find commands.
    /// For MongoDB server 3.2 and higher we'd recommend using the `find` method in this Collection for security.
    /// - parameter query: The document that we're matching against in this collection
    /// - parameter flags: The Query Flags that we'll use for this query
    /// - parameter fetchChunkSize: The initial amount of returned Documents. We recommend at least one Document.
    /// - returns: The first Document in the Response
    @warn_unused_result
    public func queryOne(matching filter: Document = [], usingFlags flags: QueryFlags = []) throws -> Document? {
        return try self.query(matching: filter, usingFlags: flags, fetching: 1).makeIterator().next()
    }
    
    
    /// Queries this collection with a Document (which comes from the Query)
    /// Can be used for DBCommands as well as find commands.
    /// For MongoDB server 3.2 and higher we'd recommend using the `find` method in this Collection for security.
    /// - parameter query: The Query that we're matching against in this collection. This query is from the MongoKitten QueryBuilder.
    /// - parameter flags: The Query Flags that we'll use for this query
    /// - parameter fetchChunkSize: The initial amount of returned Documents. We recommend at least one Document.
    /// - returns: The first Document in the Response
    @warn_unused_result
    public func queryOne(matching filter: Query, usingFlags flags: QueryFlags = []) throws -> Document? {
        return try self.queryOne(matching: filter.data, usingFlags: flags)
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
    public func find(matching filter: Document? = nil, sortedBy sort: Document? = nil, projecting projection: Document? = nil, skipping skip: Int32? = nil, limitedTo limit: Int32? = nil, withBatchSize batchSize: Int32 = 10) throws -> Cursor<Document> {
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
            
            let reply = try database.execute(command: command)
            
            guard case .Reply(_, _, _, _, _, _, let documents) = reply else {
                throw InternalMongoError.IncorrectReply(reply: reply)
            }
            
            guard let responseDoc = documents.first, cursorDoc = responseDoc["cursor"]?.documentValue else {
                throw MongoError.InvalidResponse(documents: documents)
            }
            
            return try Cursor(cursorDocument: cursorDoc, server: database.server, chunkSize: 10, transform: { $0 })
        default:
            let queryMsg = Message.Query(requestID: database.server.nextMessageID(), flags: [], collection: self, numbersToSkip: skip ?? 0, numbersToReturn: batchSize, query: filter ?? [], returnFields: projection)
            
            let id = try self.database.server.send(message: queryMsg)
            let reply = try self.database.server.await(response: id)
            
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
    public func find(matching filter: Query, sortedBy sort: Document? = nil, projecting projection: Document? = nil, skipping skip: Int32? = nil, limitedTo limit: Int32? = nil, withBatchSize batchSize: Int32 = 0) throws -> Cursor<Document> {
        return try find(matching: filter.data, sortedBy: sort, projecting: projection, skipping: skip, limitedTo: limit, withBatchSize: batchSize)
    }
    
    /// Finds Documents in this collection
    /// Cannot be used for DBCommands when using MongoDB 3.2 or higher
    /// - parameter filter: The Document filter we're using to match Documents in this collection against
    /// - parameter sort: The Sort Specification used to sort the found Documents
    /// - parameter projection: The Projection Specification used to filter which fields to return
    /// - parameter skip: The amount of Documents to skip before returning the matching Documents
    /// - returns: The found Document
    @warn_unused_result
    public func findOne(matching filter: Document? = nil, sortedBy sort: Document? = nil, projecting projection: Document? = nil, skipping skip: Int32? = nil) throws -> Document? {
        return try self.find(matching: filter, sortedBy: sort, projecting: projection, skipping: skip, limitedTo:
            1).makeIterator().next()
    }
    
    /// Finds Documents in this collection
    /// Cannot be used for DBCommands when using MongoDB 3.2 or higher
    /// - parameter filter: The QueryBuilder filter we're using to match Documents in this collection against
    /// - parameter sort: The Sort Specification used to sort the found Documents
    /// - parameter projection: The Projection Specification used to filter which fields to return
    /// - parameter skip: The amount of Documents to skip before returning the matching Documents
    /// - returns: The found Document
    @warn_unused_result
    public func findOne(matching filter: Query, sortedBy sort: Document? = nil, projecting projection: Document? = nil, skipping skip: Int32? = nil) throws -> Document? {
        return try findOne(matching: filter.data, sortedBy: sort, projecting: projection, skipping: skip)
    }
    
    // Update
    
    /// Updates a list of Documents using a counterpart Document.
    /// - parameter updates: A list of updates to be executed.
    ///     `query`: A filter to narrow down which Documents you want to update
    ///     `update`: The fields and values to update
    ///     `upsert`: If there isn't anything to update.. insert?
    ///     `multi`: Update all matching Documents instead of just one?
    /// - parameter ordered: If true, stop updating when one operation fails - defaults to true
    public func update(updates: [(filter: Document, to: Document, upserting: Bool, multiple: Bool)], stoppingOnError ordered: Bool? = nil) throws {
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        
        switch protocolVersion {
        case 2...4:
        var command: Document = ["update": self.name]
        var newUpdates = [BSONElement]()
        
        for u in updates {
            newUpdates.append(*[
                                   "q": u.filter,
                                   "u": u.to,
                                   "upsert": u.upserting,
                                   "multi": u.multiple
                ])
        }
        
        command["updates"] = Document(array: newUpdates)
        
        if let ordered = ordered {
            command["ordered"] = ordered
        }
        
        guard case .Reply(_, _, _, _, _, _, let documents) = try self.database.execute(command: command) where documents.first?["ok"]?.int32Value == 1 else {
            throw MongoError.UpdateFailure(updates: updates)
        }
        default:
            for update in updates {
                var flags: UpdateFlags = []
                
                if update.multiple {
                    flags.insert(UpdateFlags.MultiUpdate)
                }
                
                if update.upserting {
                    flags.insert(UpdateFlags.Upsert)
                }
                
                let message = Message.Update(requestID: database.server.nextMessageID(), collection: self, flags: flags, findDocument: update.filter, replaceDocument: update.to)
                try self.database.server.send(message: message)
            }
        }
    }
    
    /// Updates a Document with some new Keys and Values
    /// - parameter query: The filter to use when searching for Documents to update
    /// - parameter updated: The data to update these Documents with
    /// - parameter upsert: Insert when we can't find anything to update
    /// - parameter multi: Updates more than one result if true
    /// - parameter ordered: If true, stop updating when one operation fails - defaults to true
    public func update(matching filter: Document, to updated: Document, upserting upsert: Bool = false, multiple multi: Bool = false, stoppingOnError ordered: Bool? = nil) throws {
        return try self.update([(filter: filter, to: updated, upserting: upsert, multiple: multi)], stoppingOnError: ordered)
    }
    
    /// Updates a list of Documents using a counterpart Document.
    /// - parameter updates: A list of updates to be executed.
    ///     `query`: A QueryBuilder filter to narrow down which Documents you want to update
    ///     `update`: The fields and values to update
    ///     `upsert`: If there isn't anything to update.. insert?
    ///     `multi`: Update all matching Documents instead of just one?
    /// - parameter ordered: If true, stop updating when one operation fails - defaults to true
    public func update(updates: [(filter: Query, to: Document, upserting: Bool, multiple: Bool)], stoppingOnError ordered: Bool? = nil) throws {
        let newUpdates = updates.map { (filter: $0.filter.data, to: $0.to, upserting: $0.upserting, multiple: $0.multiple) }
        
        try self.update(newUpdates, stoppingOnError: ordered)
    }
    
    /// Updates a Document with some new Keys and Values
    /// - parameter query: The QueryBuilder filter to use when searching for Documents to update
    /// - parameter updated: The data to update these Documents with
    /// - parameter upsert: Insert when we can't find anything to update
    /// - parameter multi: Updates more than one result if true
    /// - parameter ordered: If true, stop updating when one operation fails - defaults to true
    public func update(matching filter: Query, to updated: Document, upserting upsert: Bool = false, multiple multi: Bool = false, stoppingOnError ordered: Bool? = nil) throws {
        return try self.update([(filter: filter.data, to: updated, upserting: upsert, multiple: multi)], stoppingOnError: ordered)
    }
    
    // Delete
    
    /// Removes all Documents matching the filter if they're within limit
    /// - parameter matching: A list of filters to match documents against. Any given filter can be used infinite amount of removals if `0` or otherwise as often as specified in the limit
    /// - parameter stoppingOnError: If true, stop removing when one operation fails - defaults to true
    public func remove(matching removals: [(filter: Document, limit: Int32)], stoppingOnError ordered: Bool? = nil) throws {
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        
        switch protocolVersion {
        case 2...4:
        var command: Document = ["delete": self.name]
        var newDeletes = [BSONElement]()
        
        for d in removals {
            newDeletes.append(*[
                                   "q": d.filter,
                                   "limit": d.limit
                ])
        }
        
        command["deletes"] = Document(array: newDeletes)
        
        if let ordered = ordered {
            command["ordered"] = ordered
        }
        
        let reply = try self.database.execute(command: command)
        let documents = try database.allDocuments(in: reply)
        
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
                
                let message = Message.Delete(requestID: database.server.nextMessageID(), collection: self, flags: flags, removeDocument: removal.filter)
                
                for _ in 0..<limit {
                    try self.database.server.send(message: message)
                }
            }
        }
    }
    
    /// Removes all Documents matching the filter if they're within limit
    /// - parameter matching: A list of QueryBuilder filters to match documents against. Any given filter can be used infinite amount of removals if `0` or otherwise as often as specified in the limit
    /// - parameter stoppingOnError: If true, stop removing when one operation fails - defaults to true
    public func remove(matching removals: [(filter: Query, limit: Int32)], stoppingOnError ordered: Bool? = nil) throws {
        let newRemovals = removals.map { (filter: $0.filter.data, limit: $0.limit) }
        
        try self.remove(matching: newRemovals, stoppingOnError: ordered)
    }
    
    /// Removes all Documents matching the filter if they're within limit
    /// - parameter matching: The Document filter to use when finding Documents that are going to be removed
    /// - parameter limitedTo: The amount of times this filter can be used to find and remove a Document (0 is every document)
    /// - parameter stoppingOnError: If true, stop removing when one operation fails - defaults to true
    public func remove(matching filter: Document, limitedTo limit: Int32 = 0, stoppingOnError ordered: Bool? = nil) throws {
        try self.remove(matching: [(filter: filter, limit: limit)], stoppingOnError: ordered)
    }
    
    /// Removes all Documents matching the filter if they're within limit
    /// - parameter matching: The QueryBuilder filter to use when finding Documents that are going to be removed
    /// - parameter limitedTo: The amount of times this filter can be used to find and remove a Document (0 is every document)
    /// - parameter stoppingOnError: If true, stop removing when one operation fails - defaults to true
    public func remove(matching filter: Query, limitedTo limit: Int32 = 0, stoppingOnError ordered: Bool? = nil) throws {
        try self.remove(matching: [(filter: filter.data, limit: limit)], stoppingOnError: ordered)
    }
    
    /// The drop command removes an entire collection from a database. This command also removes any indexes associated with the dropped collection.
    public func drop() throws {
        _ = try self.database.execute(command: ["drop": self.name])
    }
    
    /// Changes the name of an existing collection. This method supports renames within a single database only. To move the collection to a different database, use the `move` method on `Collection`.
    /// - parameter to: The new name for this collection
    public func rename(to newName: String) throws {
        try self.move(to: database, named: newName)
    }
    
    /// Move this collection to another database. Can also rename the collection in one go.
    /// **Users must have access to the admin database to run this command.**
    /// - parameter to: The database to move this collection to
    /// - parameter named: The new name for this collection
    public func move(to database: Database, named newName: String? = nil, overwriting dropOldTarget: Bool? = nil) throws {
        // TODO: Fail if the target database exists.
        var command: Document = [
                                    "renameCollection": self.fullName,
                                    "to": "\(database.name).\(newName ?? self.name)"
        ]
        
        if let dropOldTarget = dropOldTarget { command["dropTarget"] = dropOldTarget }
        
        _ = try self.database.server["admin"].execute(command: command)
        
        self.database = database
        self.name = newName ?? name
    }
    
    /// Returns the amount of Documents in this collection
    /// - parameter filteringBy: Optional. If specified limits the returned amount to anything matching this query
    /// - parameter limitedTo: Optional. Limits the returned amount as specified
    /// - parameter skipping: Optional. The amount of Documents to skip before counting
    @warn_unused_result
    public func count(matching filter: Document? = nil, limitedTo limit: Int32? = nil, skipping skip: Int32? = nil) throws -> Int {
        var command: Document = ["count": self.fullName]
        
        if let filter = filter {
            command["query"] = filter
        }
        
        if let skip = skip {
            command["skip"] = skip
        }
        
        let reply = try self.database.execute(command: command)
        
        guard case .Reply(_, _, _, _, _, _, let documents) = reply, let document = documents.first, let n = document["n"]?.intValue else {
            throw InternalMongoError.IncorrectReply(reply: reply)
        }
        
        return n
    }
    
    /// Returns the amount of Documents in this collection
    /// - parameter filteringBy: Optional. If specified limits the returned amount to anything matching this query
    /// - parameter limitedTo: Optional. Limits the returned amount as specified
    /// - parameter skipping: Optional. The amount of Documents to skip before counting
    @warn_unused_result
    public func count(matching query: Query, limitedTo limit: Int32? = nil, skipping skip: Int32? = nil) throws -> Int {
        return try count(matching: query.data, limitedTo: limit, skipping: skip)
    }
    
    /// Returns all distinct values for a key in this collection. Allows filtering using query
    /// - parameter key: The key that we distinct on
    /// - parameter query: The Document query used to filter through the returned results
    /// - returns: A list of all distinct values for this key
    @warn_unused_result
    public func distinct(key: String, usingFilter filter: Document? = nil) throws -> [String]? {
        var command: Document = ["distinct": self.name, "key": key]
        
        if let filter = filter {
            command["query"] = filter
        }
        
        return try database.firstDocument(in: try self.database.execute(command: command))["values"]?.documentValue?.arrayValue.flatMap({ $0.stringValue })
    }
    
    /// Returns all distinct values for a key in this collection. Allows filtering using query
    /// - parameter key: The key that we distinct on
    /// - parameter query: The query used to filter through the returned results
    /// - returns: A list of all distinct values for this key
    @warn_unused_result
    public func distinct(key: String, usingFilter query: Query) throws -> [String]? {
        return try self.distinct(key, usingFilter: query.data)
    }
    
    public func createIndex(with keys: [(key: String, ascending: Bool)], named name: String, filter: Document?, buildInBackground: Bool, unique: Bool) throws {
        try self.create(indexes: [(name: name, keys: keys, filter: filter, buildInBackground: buildInBackground, unique: unique)])
    }
    
    /// Creates an index using the given parameters
    public func create(indexes indexes: [(name: String, keys: [(key: String, ascending: Bool)], filter: Document?, buildInBackground: Bool, unique: Bool)]) throws {
        guard let wireVersion = database.server.serverData?.maxWireVersion where wireVersion > 2 else {
            throw MongoError.UnsupportedOperations
        }

        var indexesDoc: Document = []

        for index in indexes {
            var keys: Document = []
            
            for key in index.keys {
                keys[key.key] = key.ascending ? Int32(1) : Int32(-1)
            }
            
            keys.enforceArray()
            
            var indexDocument = *[
                                               "key": keys,
                                               "name": index.name
            ]
            
            if let filter = index.filter {
                indexDocument["partialFilterExpression"] = filter
            }
            
            if index.buildInBackground {
                indexDocument["background"] = true
            }
            
            if index.unique {
                indexDocument["unique"] = true
            }
            
            indexesDoc += indexDocument
        }
        
        indexesDoc.enforceArray()
        
        _ = try database.execute(command: ["createIndexes": self.name, "indexes": indexesDoc])
    }
    
    /// Remove the index specified
    /// Warning: Write-locks the database whilst this process is executed
    /// - parameter indexName: The index name (as specified when creating the index) that will removed. `*` for all indexes
    public func dropIndexes(indexName: String) throws {
        _ = try database.execute(command: ["dropIndexes": self.name, "index": indexName])
    }
    
    /// TODO: Make this work?
    /// Lists all indexes for this collection
    /// - returns: A Cursor pointing to the Index results
    @warn_unused_result
    public func listIndexes() throws -> Cursor<Document> {
        guard let wireVersion = database.server.serverData?.maxWireVersion where wireVersion > 3 else {
            throw MongoError.UnsupportedOperations
        }
        
        let result = try database.firstDocument(in: try database.execute(command: ["listIndexes": self.name]))
        
        guard let cursorDocument = result["cursor"]?.documentValue else {
            throw MongoError.CursorInitializationError(cursorDocument: result)
        }
        
        return try Cursor(cursorDocument: cursorDocument, server: database.server, chunkSize: 10, transform: { $0 })
    }
}