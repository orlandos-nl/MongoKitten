//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//
import Foundation
import BSON

public typealias MongoCollection = Collection

/// Represents a single MongoDB collection.
///
/// **### Definition ###**
///
/// A grouping of MongoDB documents. A collection is the equivalent of an RDBMS table. A collection exists within a single database. Collections do not enforce a schema. Documents within a collection can have different fields. Typically, all documents in a collection have a similar or related purpose. See Namespaces.
public final class Collection {
    /// The Database this collection is in
    public private(set) var database: Database
    
    /// The collection name
    public private(set) var name: String
    
    #if Xcode
    func debugQuickLookObject() -> AnyObject {
        var userInfo = ""
        
        if let username = database.server.clientSettings.credentials?.username {
            userInfo = "\(username):*********@"
        }
        
        var collectionData = ""
        
        if let documentCount = try? self.count() {
            collectionData = "Document count: \(documentCount)\n"
        } else {
            collectionData = "Unable to fetch collection data"
        }
        
        return NSString(string: "mongodb://\(userInfo)\(database.server.hostname)/\(self.fullName)\n\n\(collectionData)")
    }
    #endif
    
    /// The full (computed) collection name. Created by adding the Database's name with the Collection's name with a dot to seperate them
    /// Will be empty
    public var fullName: String {
        return "\(database.name).\(name)"
    }
    
    /// The default ReadConcern for this Collection.
    ///
    /// When a ReadConcern is provided in the method call it'll still override this
    private var defaultReadConcern: ReadConcern? = nil
    
    /// The default WriteConcern for this Collection.
    ///
    /// When a WriteConcern is provided in the method call it'll still override this
    private var defaultWriteConcern: WriteConcern? = nil
    
    /// Sets or gets the default write concern at the collection level
    public var writeConcern: WriteConcern? {
        get {
            return self.defaultWriteConcern ?? database.writeConcern
        }
        set {
            self.defaultWriteConcern = newValue
        }
    }
    
    /// Sets or gets the default read concern at the collection level
    public var readConcern: ReadConcern? {
        get {
            return self.defaultReadConcern ?? database.readConcern
        }
        set {
            self.defaultReadConcern = newValue
        }
    }
    
    /// The default Collation for collections in this Server.
    ///
    /// When a Collation is provided in the method call it'll still override this
    private var defaultCollation: Collation? = nil
    
    /// Sets or gets the default read concern at the collection level
    public var collation: Collation? {
        get {
            return self.defaultCollation ?? database.collation
        }
        set {
            self.defaultCollation = newValue
        }
    }
    
    /// Initializes this collection with a database and name
    ///
    /// - parameter name: The collection name
    /// - parameter database: The database this `Collection` exists in
    internal init(named name: String, in database: Database) {
        self.database = database
        self.name = name
    }
    
    // MARK: - CRUD Operations
    
    // Create
    
    /// Insert a single document in this collection
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/insert/#dbcmd.insert
    ///
    /// - parameter document: The BSON Document to be inserted
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: The inserted document's id
    @discardableResult
    public func insert(_ document: Document) throws -> ValueConvertible {
        let result = try self.insert([document])
        
        guard let newId = result.first else {
            database.server.logger.error("No identifier could be generated")
            throw MongoError.insertFailure(documents: [document], error: nil)
        }
        
        return newId
    }
    
    /// TODO: Detect how many bytes are being sent. Max is 48000000 bytes or 48MB
    ///
    /// Inserts multiple documents in this collection and adds a BSON ObjectId to documents that do not have an "_id" field
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/insert/#dbcmd.insert
    ///
    /// - parameter documents: The BSON Documents that should be inserted
    /// - parameter ordered: On true we'll stop inserting when one document fails. On false we'll ignore failed inserts
    /// - parameter timeout: A custom timeout. The default timeout is 60 seconds + 1 second for every 50 documents, so when inserting 5000 documents at once, the timeout is 560 seconds.
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: The documents' ids
    @discardableResult
    public func insert(_ documents: [Document], stoppingOnError ordered: Bool? = nil, writeConcern: WriteConcern? = nil, timeout customTimeout: TimeInterval? = nil) throws -> [ValueConvertible] {
        let timeout: TimeInterval = customTimeout ?? (database.server.defaultTimeout + (Double(documents.count) / 50))
        
        var documents = documents
        var newIds = [ValueConvertible]()
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        
        while !documents.isEmpty {
            if protocolVersion >= 2 {
                var command: Document = ["insert": self.name]
                
                let commandDocuments = documents[0..<min(1000, documents.count)].map({ (input: Document) -> ValueConvertible in
                    if let id = input[raw: "_id"] {
                        newIds.append(id)
                        return input
                    } else {
                        var output = input
                        let oid = ObjectId()
                        output[raw: "_id"] = oid
                        newIds.append(oid)
                        return output
                    }
                })
                
                documents.removeFirst(min(1000, documents.count))
                
                command["documents"] = Document(array: commandDocuments)
                
                if let ordered = ordered {
                    command["ordered"] = ordered
                }
                
                command[raw: "writeConcern"] = writeConcern ?? self.writeConcern
                
                let reply = try self.database.execute(command: command, until: timeout)
                guard case .Reply(_, _, _, _, _, _, let replyDocuments) = reply else {
                    throw MongoError.insertFailure(documents: documents, error: nil)
                }
                
                guard replyDocuments.first?["ok"] as Int? == 1 && (replyDocuments.first?["writeErrors"] as Document? ?? [:]).count == 0 else {
                    throw MongoError.insertFailure(documents: documents, error: replyDocuments.first)
                }
            } else {
                let connection = try database.server.reserveConnection(writing: true, authenticatedFor: self.database)
                
                defer {
                    database.server.returnConnection(connection)
                }
                
                let commandDocuments = Array(documents[0..<min(1000, documents.count)])
                documents.removeFirst(min(1000, documents.count))
                
                let insertMsg = Message.Insert(requestID: database.server.nextMessageID(), flags: [], collection: self, documents: commandDocuments)
                _ = try self.database.server.send(message: insertMsg, overConnection: connection)
            }
        }
        
        return newIds
    }
    
    // Read
    
    /// Executes a query on this `Collection` with a `Document`
    ///
    /// This is used to execute DBCommands. For finding `Document`s we recommend the `find` command
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/mongodb-wire-protocol/
    ///
    /// - parameter query: The document that we're matching against in this collection
    /// - parameter flags: The Query Flags that we'll use for this query
    /// - parameter fetchChunkSize: The initial amount of returned Documents. We recommend at least 10 Documents.
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: A Cursor pointing to the response Documents.
    public func execute(command: Document = [], usingFlags flags: QueryFlags = [], fetching fetchChunkSize: Int32 = 100, timeout: TimeInterval = 0) throws -> Cursor<Document> {
        let timeout = timeout > 0 ? timeout : database.server.defaultTimeout
        
        let connection = try database.server.reserveConnection(writing: true, authenticatedFor: self.database)
        
        defer {
            database.server.returnConnection(connection)
        }
        
        let queryMsg = Message.Query(requestID: database.server.nextMessageID(), flags: flags, collection: self, numbersToSkip: 0, numbersToReturn: fetchChunkSize, query: command, returnFields: nil)
        
        let response = try self.database.server.sendAndAwait(message: queryMsg, overConnection: connection, timeout: timeout)
        guard let cursor = Cursor(namespace: self.fullName, collection: self, reply: response, chunkSize: fetchChunkSize, transform: { $0 }) else {
            throw MongoError.invalidReply
        }
        
        return cursor
    }
    
    /// Finds `Document`s in this `Collection`
    ///
    /// Can be used to execute DBCommands in MongoDB 2.6 and below. Be careful!
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/find/#dbcmd.find
    ///
    /// - parameter filter: The filter we're using to match Documents in this collection against
    /// - parameter sort: The Sort Specification used to sort the found Documents
    /// - parameter projection: The Projection Specification used to filter which fields to return
    /// - parameter skip: The amount of Documents to skip before returning the matching Documents
    /// - parameter limit: The maximum amount of matching documents to return
    /// - parameter batchSize: The initial amount of Documents to return.
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: A cursor pointing to the found Documents
    public func find(matching filter: Query? = nil, sortedBy sort: Sort? = nil, projecting projection: Projection? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, skipping skip: Int32? = nil, limitedTo limit: Int32? = nil, withBatchSize batchSize: Int32 = 100) throws -> Cursor<Document> {
        if database.server.buildInfo.version >= Version(3,2,0) {
            var command: Document = ["find": self.name]
            
            if let filter = filter {
                command[raw: "filter"] = filter
            }
            
            if let sort = sort {
                command[raw: "sort"] = sort
            }
            
            if let projection = projection {
                command[raw: "projection"] = projection
            }
            
            if let skip = skip {
                command["skip"] = Int32(skip)
            }
            
            if let limit = limit {
                command["limit"] = Int32(limit)
            }
            
            command[raw: "readConcern"] = readConcern ?? self.readConcern
            command[raw: "collation"] = collation ?? self.collation
            
            command["batchSize"] = Int32(batchSize)
            
            let reply = try database.execute(command: command, writing: false)
            
            guard case .Reply(_, _, _, _, _, _, let documents) = reply else {
                throw InternalMongoError.incorrectReply(reply: reply)
            }
            
            guard let responseDoc = documents.first, let cursorDoc = responseDoc["cursor"] as Document? else {
                throw MongoError.invalidResponse(documents: documents)
            }
            
            return try Cursor(cursorDocument: cursorDoc, collection: self, chunkSize: batchSize, transform: { doc in
                return doc
            })
        } else {
            let connection = try database.server.reserveConnection(authenticatedFor: self.database)
            
            defer {
                database.server.returnConnection(connection)
            }
            
            let queryMsg = Message.Query(requestID: database.server.nextMessageID(), flags: [], collection: self, numbersToSkip: skip ?? 0, numbersToReturn: batchSize, query: filter?.queryDocument ?? [], returnFields: projection?.document)
            
            let reply = try self.database.server.sendAndAwait(message: queryMsg, overConnection: connection)
            
            guard case .Reply(_, _, _, let cursorID, _, _, var documents) = reply else {
                throw InternalMongoError.incorrectReply(reply: reply)
            }
            
            if let limit = limit {
                if documents.count > Int(limit) {
                    documents.removeLast(documents.count - Int(limit))
                }
            }
            
            var returned: Int32 = 0
            
            return Cursor(namespace: self.fullName, collection: self, cursorID: cursorID, initialData: documents, chunkSize: batchSize, transform: { doc in
                if let limit = limit {
                    guard returned < limit else {
                        return nil
                    }
                    
                    returned += 1
                }
                return doc
            })
        }
    }
    
    /// Finds Documents in this collection
    ///
    /// Can be used to execute DBCommands in MongoDB 2.6 and below
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/find/#dbcmd.find
    ///
    /// - parameter filter: The QueryBuilder filter we're using to match Documents in this collection against
    /// - parameter sort: The Sort Specification used to sort the found Documents
    /// - parameter projection: The Projection Specification used to filter which fields to return
    /// - parameter skip: The amount of Documents to skip before returning the matching Documents
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: The found Document
    public func findOne(matching filter: Query? = nil, sortedBy sort: Sort? = nil, projecting projection: Projection? = nil, skipping skip: Int32? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil) throws -> Document? {
        return try self.find(matching: filter, sortedBy: sort, projecting: projection, readConcern: readConcern, collation: collation, skipping: skip, limitedTo:
            1).next()
    }
    
    // Update
    
    /// Updates a list of `Document`s using a counterpart `Document`.
    ///
    /// In most cases the `$set` operator is useful for updating only parts of a `Document`
    /// As described here: https://docs.mongodb.com/manual/reference/operator/update/set/#up._S_set
    ///
    /// For more information about this command: https://docs.mongodb.com/manual/reference/command/update/#dbcmd.update
    ///
    /// TODO: Work on improving the updatefailure.  We don't handle writerrrors. Try using a normal query with multiple on true
    ///
    /// - parameter updates: A list of updates to be executed.
    ///     `query`: A filter to narrow down which Documents you want to update
    ///     `update`: The fields and values to update
    ///     `upsert`: If there isn't anything to update.. insert?
    ///     `multi`: Update all matching Documents instead of just one?
    /// - parameter ordered: If true, stop updating when one operation fails - defaults to true
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: The amount of updated documents
    @discardableResult
    public func update(_ updates: [(filter: Query, to: Document, upserting: Bool, multiple: Bool)], writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        
        if protocolVersion >= 2 {
            var command: Document = ["update": self.name]
            var newUpdates = [ValueConvertible]()
            
            for u in updates {
                newUpdates.append([
                    "q": u.filter.queryDocument,
                    "u": u.to,
                    "upsert": u.upserting,
                    "multi": u.multiple
                    ] as Document)
            }
            
            command["updates"] = Document(array: newUpdates)
            
            if let ordered = ordered {
                command["ordered"] = ordered
            }
            
            command[raw: "writeConcern"] = writeConcern ??  self.writeConcern
            
            let reply = try self.database.execute(command: command)
            guard case .Reply(_, _, _, _, _, _, let documents) = reply else {
                throw MongoError.updateFailure(updates: updates, error: nil)
            }
            
            guard documents.first?["ok"] as Int? == 1 && (documents.first?["writeErrors"] as Document? ?? [:]).count == 0 else {
                throw MongoError.updateFailure(updates: updates, error: documents.first)
            }
            
            return documents.first?["nModified"] as Int? ?? 0
        } else {
            let connection = try database.server.reserveConnection(writing: true, authenticatedFor: self.database)
            
            defer {
                database.server.returnConnection(connection)
            }
            
            for update in updates {
                var flags: UpdateFlags = []
                
                if update.multiple {
                    // TODO: Remove this assignment when the standard library is updated.
                    let _ = flags.insert(UpdateFlags.MultiUpdate)
                }
                
                if update.upserting {
                    // TODO: Remove this assignment when the standard library is updated.
                    let _ = flags.insert(UpdateFlags.Upsert)
                }
                
                let message = Message.Update(requestID: database.server.nextMessageID(), collection: self, flags: flags, findDocument: update.filter.queryDocument, replaceDocument: update.to)
                try self.database.server.send(message: message, overConnection: connection)
                // TODO: Check for errors
            }
            
            return updates.count
        }
    }
    
    /// Updates a `Document` using a counterpart `Document`.
    ///
    /// In most cases the `$set` operator is useful for updating only parts of a `Document`
    /// As described here: https://docs.mongodb.com/manual/reference/operator/update/set/#up._S_set
    ///
    /// For more information about this command: https://docs.mongodb.com/manual/reference/command/update/#dbcmd.update
    ///
    /// - parameter filter: The QueryBuilder filter to use when searching for Documents to update
    /// - parameter updated: The data to update these Documents with
    /// - parameter upsert: Insert when we can't find anything to update
    /// - parameter multi: Updates more than one result if true
    /// - parameter ordered: If true, stop updating when one operation fails - defaults to true
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    @discardableResult
    public func update(matching filter: Query = [:], to updated: Document, upserting upsert: Bool = false, multiple multi: Bool = false, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        return try self.update([(filter: filter, to: updated, upserting: upsert, multiple: multi)], writeConcern: writeConcern, stoppingOnError: ordered)
    }
    
    // Delete
    
    /// Removes all `Document`s matching the `filter` until the `limit` is reached
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/delete/#dbcmd.delete
    ///
    /// - parameter removals: A list of filters to match documents against. Any given filter can be used infinite amount of removals if `0` or otherwise as often as specified in the limit
    /// - parameter stoppingOnError: If true, stop removing when one operation fails - defaults to true
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    @discardableResult
    public func remove(matching removals: [(filter: Query, limit: Int32)], writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        
        if protocolVersion >= 2 {
            var command: Document = ["delete": self.name]
            var newDeletes = [ValueConvertible]()
            
            for d in removals {
                newDeletes.append([
                    "q": d.filter.queryDocument,
                    "limit": d.limit
                    ] as Document)
            }
            
            command["deletes"] = Document(array: newDeletes)
            
            if let ordered = ordered {
                command["ordered"] = ordered
            }
            
            command[raw: "writeConcern"] = writeConcern ?? self.writeConcern
            
            let reply = try self.database.execute(command: command)
            let documents = try allDocuments(in: reply)
            
            guard let document = documents.first, document["ok"] as Int? == 1 else {
                throw MongoError.removeFailure(removals: removals, error: documents.first)
            }
            
            return document["n"] as Int? ?? 0
            
            // If we're talking to an older MongoDB server
        } else {
            let connection = try database.server.reserveConnection(authenticatedFor: self.database)
            
            defer {
                database.server.returnConnection(connection)
            }
            
            for removal in removals {
                var flags: DeleteFlags = []
                
                // If the limit is 0, make the for loop run exactly once so the message sends
                // If the limit is not 0, set the limit properly
                let limit = removal.limit == 0 ? 1 : removal.limit
                
                // If the limit is not '0' and thus removes a set amount of documents. Set it to RemoveOne so we'll remove one document at a time using the older method
                if removal.limit != 0 {
                    // TODO: Remove this assignment when the standard library is updated.
                    let _ = flags.insert(DeleteFlags.RemoveOne)
                }
                
                let message = Message.Delete(requestID: database.server.nextMessageID(), collection: self, flags: flags, removeDocument: removal.filter.queryDocument)
                
                for _ in 0..<limit {
                    try self.database.server.send(message: message, overConnection: connection)
                }
            }
            
            return removals.count
        }
    }
    
    /// Removes `Document`s matching the `filter` until the `limit` is reached
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/delete/#dbcmd.delete
    ///
    /// - parameter matching: The QueryBuilder filter to use when finding Documents that are going to be removed
    /// - parameter limitedTo: The amount of times this filter can be used to find and remove a Document (0 is every document)
    /// - parameter stoppingOnError: If true, stop removing when one operation fails - defaults to true
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    @discardableResult
    public func remove(matching filter: Query, limitedTo limit: Int32 = 0, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        return try self.remove(matching: [(filter: filter, limit: limit)], writeConcern: writeConcern, stoppingOnError: ordered)
    }
    
    /// The drop command removes an entire collection from a database. This command also removes any indexes associated with the dropped collection.
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/drop/#dbcmd.drop
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func drop() throws {
        _ = try self.database.execute(command: ["drop": self.name])
    }
    
    /// Changes the name of an existing collection. This method supports renames within a single database only. To move the collection to a different database, use the `move` method on `Collection`.
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/renameCollection/#dbcmd.renameCollection
    ///
    /// - parameter to: The new name for this collection
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func rename(to newName: String) throws {
        try self.move(toDatabase: database, renamedTo: newName)
    }
    
    /// Move this collection to another database. Can also rename the collection in one go.
    ///
    /// **Users must have access to the admin database to run this command.**
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/renameCollection/#dbcmd.renameCollection
    ///
    /// - parameter to: The database to move this collection to
    /// - parameter named: The new name for this collection
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func move(toDatabase database: Database, renamedTo newName: String? = nil, overwritingExistingCollection dropOldTarget: Bool? = nil) throws {
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
    
    /// Counts the amount of `Document`s matching the `filter`. Stops counting when the `limit` it reached
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/count/#dbcmd.count
    ///
    /// - parameter filter: Optional. If specified limits the returned amount to anything matching this query
    /// - parameter limit: Optional. Limits the amount of scanned `Document`s as specified
    /// - parameter skip: Optional. The amount of Documents to skip before counting
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: The amount of matching `Document`s
    public func count(matching filter: Query? = nil, limitedTo limit: Int32? = nil, skipping skip: Int32? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil) throws -> Int {
        var command: Document = ["count": self.name]
        
        if let filter = filter?.queryDocument {
            command["query"] = filter
        }
        
        if let skip = skip {
            command["skip"] = Int32(skip)
        }
        
        if let limit = limit {
            command["limit"] = Int32(limit)
        }
        
        command[raw: "readConcern"] = readConcern ?? self.readConcern
        command[raw: "collation"] = collation ?? self.collation
        
        let reply = try self.database.execute(command: command, writing: false)
        
        guard case .Reply(_, _, _, _, _, _, let documents) = reply, let document = documents.first else {
            throw InternalMongoError.incorrectReply(reply: reply)
        }
        
        guard let n = document["n"] as Int?, document["ok"] as Int? == 1 else {
            throw InternalMongoError.incorrectReply(reply: reply)
        }
        
        return n
    }
    
    /// `findAndModify` only has two operations that can be used. Update and Delete
    ///
    /// To make these types of operations easily accessible in `findAndModify` this enum exists
    public enum FindAndModifyOperation {
        /// Remove the found `Document`
        case remove
        
        /// Update the found `Document` with the provided `Document`
        ///
        /// - parameter with: Updated the found `Document` with this `Document`
        /// - parameter returnModified: Return the modified `Document`?
        /// - parameter upserting: Insert if it doesn't exist yet
        case update(with: Document, returnModified: Bool, upserting: Bool)
    }
    
    /// Finds and modifies the first `Document` in this `Collection`. If a query/filter is provided that'll be used to find this `Document`.
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/findAndModify/#dbcmd.findAndModify
    ///
    /// - parameter query: The `Query` to match the `Document`s in the `Collection` against
    /// - parameter sort: The sorting specification to use while searching
    /// - parameter action: A `FindAndModifyOperation` that specified which action to execute and it's required metadata
    /// - parameter projection: Which fields to project and how according to projection specification
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: The `Value` received from the server as specified in the link of the additional information
    public func findAndModify(matching query: Query? = nil, sortedBy sort: Sort? = nil, action: FindAndModifyOperation, projection: Projection? = nil) throws -> ValueConvertible {
        var command: Document = ["findAndModify": self.name]
        
        if let query = query {
            command["query"] = query.queryDocument
        }
        
        if let sort = sort {
            command.updateValue(sort, forKey: "sort")
        }
        
        switch action {
        case .remove:
            command["remove"] = true
        case .update(let with, let new, let upsert):
            command["update"] = with
            command["new"] = new
            command["upsert"] = upsert
        }
        
        if let projection = projection {
            command.updateValue(projection, forKey: "fields")
        }
        
        let document = try firstDocument(in: try database.execute(command: command))
        
        guard document["ok"] as Int? == 1 && (document["writeErrors"] as Document? ?? [:]).count == 0 else {
            throw MongoError.commandFailure(error: document)
        }
        
        return document[raw: "value"] ?? Null()
    }
    
    /// Returns all distinct values for a key in this collection. Allows filtering using query
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/distinct/#dbcmd.distinct
    ///
    /// - parameter on: The key that we distinct on
    /// - parameter query: The Document query used to filter through the returned results
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: A list of all distinct values for this key
    public func distinct(onField key: String, usingFilter filter: Document? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil) throws -> [ValueConvertible]? {
        var command: Document = ["distinct": self.name, "key": key]
        
        if let filter = filter {
            command["query"] = filter
        }
        
        command[raw: "readConcern"] = readConcern ?? self.readConcern
        command[raw: "collation"] = collation ?? self.collation
        
        return try firstDocument(in: try self.database.execute(command: command, writing: false))[raw: "values"]?.documentValue?.arrayValue ?? []
    }
    
    /// Returns all distinct values for a key in this collection. Allows filtering using query
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/distinct/#dbcmd.distinct
    ///
    /// - parameter on: The key that we distinct on
    /// - parameter query: The query used to filter through the returned results
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: A list of all distinct values for this key
    public func distinct(on key: String, usingFilter query: Query) throws -> [ValueConvertible]? {
        return try self.distinct(onField: key, usingFilter: query.queryDocument)
    }
    
    /// Creates an `Index` in this `Collection` on the specified keys.
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/createIndexes/#dbcmd.createIndexes
    ///
    /// - parameter keys: A Document with a `String` as the key to index and `ascending` as a `Bool`
    /// - parameter name: The name to identify the index
    /// - parameter filter: Only index `Document`s matching this filter
    /// - parameter buildInBackground: Builds the index in the background so that this operation doesn't block other database activities.
    /// - parameter unique: Used to create unique fields like usernames. Default should be `false`
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func createIndex(named name: String? = nil, withParameters parameters: IndexParameter...) throws {
        try self.createIndexes([(name: name, parameters: parameters)])
    }
    
    /// Creates multiple indexes as specified
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/createIndexes/#dbcmd.createIndexes
    ///
    /// - parameter indexes: The indexes to create using a Tuple as specified in `createIndex`
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func createIndexes(_ indexes: [(name: String?, parameters: [IndexParameter])]) throws {
        guard let wireVersion = database.server.serverData?.maxWireVersion , wireVersion >= 2 else {
            throw MongoError.unsupportedOperations
        }
        
        var indexDocs = [ValueConvertible]()
        
        for index in indexes {
            var indexDocument: Document = [
                "name": index.name
            ]
            
            for parameter in index.parameters {
                indexDocument += parameter.document
            }
            
            indexDocs.append(indexDocument)
        }
        
        
        let document = try firstDocument(in: try database.execute(command: ["createIndexes": self.name, "indexes": Document(array: indexDocs)]))
        
        guard document["ok"] as Int? == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Remove the index specified
    /// Warning: Write-locks the database whilst this process is executed
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/dropIndexes/#dbcmd.dropIndexes
    ///
    /// - parameter index: The index name (as specified when creating the index) that will removed. `*` for all indexes
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func dropIndex(named index: String) throws {
        let reply = try database.execute(command: ["dropIndexes": self.name, "index": index])
        
        let dropIndexResponse = try firstDocument(in: reply)
        guard dropIndexResponse["ok"] as Int? == 1 else {
            throw MongoError.commandFailure(error: dropIndexResponse)
        }
    }
    
    /// Lists all indexes for this collection
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/listIndexes/#dbcmd.listIndexes
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: A Cursor pointing to the Index results
    public func listIndexes() throws -> Cursor<Document> {
        guard database.server.buildInfo.version >= Version(3,0,0) else {
            throw MongoError.unsupportedOperations
        }
        
        let result = try firstDocument(in: try database.execute(command: ["listIndexes": self.name], writing: false))
        
        guard let cursorDocument = result["cursor"] as Document? else {
            throw MongoError.cursorInitializationError(cursorDocument: result)
        }
        
        let connection = try database.server.reserveConnection(authenticatedFor: self.database)
        
        defer {
            database.server.returnConnection(connection)
        }
        
        return try Cursor(cursorDocument: cursorDocument, collection: self, chunkSize: 100, transform: { $0 })
    }
    
    /// Modifies the collection. Requires access to `collMod`
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/collMod/#dbcmd.collMod
    ///
    /// You can use this method, for example, to change the validator on a collection:
    ///
    ///     collection.modify(flags: ["validator": ["name": ["$type": "string"]]])
    ///
    /// - parameter flags: The modification you want to perform. See the MongoDB documentation for more information.
    ///
    /// - throws: When MongoDB doesn't return a document indicating success, we'll throw a `MongoError.commandFailure()` containing the error document sent by the server
    /// - throws: When the `flags` document contains the key `collMod`, which is prohibited.
    public func modify(flags: Document) throws {
        guard flags[raw: "collMod"] == nil else {
            throw MongoError.commandError(error: "Cannot execute modify() on \(self.description): document `flags` contains prohibited key `collMod`.")
        }
        
        let command = ["collMod": self.name] as Document
        
        let result = try firstDocument(in: database.execute(command: command + flags))
        
        guard result["ok"] as Int? == 1 else {
            throw MongoError.commandFailure(error: result)
        }
    }
    
    /// Uses the aggregation pipeline to process documents into aggregated results.
    ///
    /// See [the MongoDB docs on the aggregation pipeline](https://docs.mongodb.org/manual/reference/operator/aggregation-pipeline/) for more information.
    ///
    /// - parameter pipeline: An array of aggregation pipeline stages that process and transform the document stream as part of the aggregation pipeline.
    /// - parameter explain: Specifies to return the information on the processing of the pipeline.
    /// - parameter allowDiskUse: Enables writing to temporary files. When set to true, aggregation stages can write data to the _tmp subdirectory in the dbPath directory.
    /// - parameter cursorOptions: Specify a document that contains options that control the creation of the cursor object.
    /// - parameter bypassDocumentValidation: Available only if you specify the $out aggregation operator. Enables aggregate to bypass document validation during the operation. This lets you insert documents that do not meet the validation requirements. *Available for MongoDB 3.2 and later versions*
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: A `Cursor` pointing to the found `Document`s
    public func aggregate(pipeline: AggregationPipeline, explain: Bool? = nil, allowDiskUse: Bool? = nil, cursorOptions: Document = ["batchSize": 100], bypassDocumentValidation: Bool? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil) throws -> Cursor<Document> {
        // construct command. we always use cursors in MongoKitten, so that's why the default value for cursorOptions is an empty document.
        var command: Document = ["aggregate": self.name, "pipeline": pipeline.pipelineDocument, "cursor": cursorOptions]
        
        command[raw: "readConcern"] = readConcern ?? self.readConcern
        command[raw: "collation"] = collation ?? self.collation
        
        if let explain = explain { command["explain"] = explain }
        if let allowDiskUse = allowDiskUse { command["allowDiskUse"] = allowDiskUse }
        if let bypassDocumentValidation = bypassDocumentValidation { command["bypassDocumentValidation"] = bypassDocumentValidation }
        
        // execute and construct cursor
        let reply = try database.execute(command: command)
        
        guard case .Reply(_, _, _, _, _, _, let documents) = reply else {
            throw InternalMongoError.incorrectReply(reply: reply)
        }
        
        guard let responseDoc = documents.first, let cursorDoc = responseDoc["cursor"] as Document? else {
            throw MongoError.invalidResponse(documents: documents)
        }
        
        return try Cursor(cursorDocument: cursorDoc, collection: self, chunkSize: (cursorOptions["batchSize"] as Int32?) ?? 100, transform: { $0 })
    }
}

extension Collection: CustomStringConvertible {
    public var description: String {
        return "MongoKitten.Collection<\(database.server.hostname)/\(self.fullName)>"
    }
}
