//
//  File.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 08/03/2017.
//
//

import Dispatch
import BSON
import Dispatch

/// Makes it internally queryable
protocol CollectionQueryable {
    /// The full collection name
    var fullCollectionName: String { get }
    
    /// The short collection name
    var collectionName: String { get }
    
    /// The collection object that's being queried
    var collection: Collection { get }
    
    /// The database that this collection resides in
    var database: Database { get }
    
    /// The read concern to apply by default
    var readConcern: ReadConcern? { get set }
    
    /// The write concern to apply by default
    var writeConcern: WriteConcern? { get set }
    
    /// The collation to apply by default
    var collation: Collation? { get set }
    
    /// The timeout to apply by default
    var timeout: DispatchTimeInterval? { get set }
}

/// Internal functions for common interactions with MongoDB (CRUD operations)
extension CollectionQueryable {
    /// The read concern to apply by default
    var readConcern: ReadConcern? {
        get {
            return collection.readConcern
        }
        set {
            collection.readConcern = newValue
        }
    }
    
    /// The write concern to apply by default
    var writeConcern: WriteConcern? {
        get {
            return collection.writeConcern
        }
        set {
            collection.writeConcern = newValue
        }
    }
    
    /// The collation to apply by default
    var collation: Collation? {
        get {
            return collection.collation
        }
        set {
            collection.collation = newValue
        }
    }
    
    /// The timeout to apply by default
    var timeout: DispatchTimeInterval? {
        get {
            return collection.timeout
        }
        set {
            collection.timeout = newValue
        }
    }
    
    /// The collection's full name
    var fullCollectionName: String {
        return collection.fullName
    }
    
    /// The collection's "simple" name
    var collectionName: String {
        return collection.name
    }
    
    /// The database this Collection resides in
    var database: Database {
        return collection.database
    }
    
    /// Inserts a set of Documents
    ///
    /// - parameter documents: The documents to insert
    /// - parameter ordered: When true, stops inserting when an error occurs
    /// - parameter writeConcern: The write concern to use on the server
    /// - parameter timeout: The timeout to wait for
    /// - parameter connection: The connection to use
    ///
    /// - throws: An `InsertError` when a write error occurs
    func insert(documents: [Document], ordered: Bool?, writeConcern: WriteConcern?, timeout: DispatchTimeInterval?, connection: Connection?) throws -> [BSON.Primitive] {
        let timeout: DispatchTimeInterval = timeout ?? .seconds(Int(database.server.defaultTimeout + (Double(documents.count) / 50)))
        
        var newIds = [Primitive]()
        var documents = documents.map({ (input: Document) -> Document in
            if let id = input["_id"] {
                newIds.append(id)
                return input
            } else {
                var output = input
                let oid = ObjectId()
                output["_id"] = oid
                newIds.append(oid)
                return output
            }
        })
        
        var errors = Array<InsertErrors.InsertError>()
        
        func throwErrors() -> InsertErrors {
            let positions = errors.flatMap { insertError in
                return insertError.writeErrors.flatMap { writeError in
                    return writeError.index
                }
            }.reduce([], +)
            
            for position in positions.reversed() {
                newIds.remove(at: position)
            }
            
            return InsertErrors(errors: errors, successfulIds: newIds)
        }
        
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        var position = 0
        
        let newConnection: Connection
        
        if let connection = connection {
            newConnection = connection
        } else {
            newConnection = try self.database.server.reserveConnection(writing: true, authenticatedFor: self.database)
        }
        
        defer {
            if connection == nil {
                self.database.server.returnConnection(newConnection)
            }
        }
        
        while position < documents.count {
            defer { position += 1000 }
            
            if protocolVersion >= 2 {
                var command: Document = ["insert": self.collectionName]
                
                command["documents"] = Document(array: Array(documents[position..<Swift.min(position + 1000, documents.count)]))
                
                if let ordered = ordered {
                    command["ordered"] = ordered
                }
                
                command["writeConcern"] = writeConcern ?? self.writeConcern
                
                let reply = try self.database.execute(command: command, using: newConnection)
                
                if let writeErrors = Document(reply.documents.first?["writeErrors"]) {
                    guard let documents = Document(command["documents"]) else {
                        throw MongoError.invalidReply
                    }
                    
                    let writeErrors = try writeErrors.arrayValue.flatMap { value -> InsertErrors.InsertError.WriteError in
                        guard let document = Document(value),
                            let index = Int(document["index"]),
                            let code = Int(document["code"]),
                            let message = String(document["errmsg"]),
                            index < documents.count,
                            let affectedDocument = Document(documents[index]) else {
                                throw MongoError.invalidReply
                        }
                        
                        return InsertErrors.InsertError.WriteError(index: index, code: code, message: message, affectedDocument: affectedDocument)
                    }
                    
                    errors.append(InsertErrors.InsertError(writeErrors: writeErrors))
                }
                
                guard Int(reply.documents.first?["ok"]) == 1 else {
                    throw throwErrors()
                }
            } else {
                
                let commandDocuments = Array(documents[position..<Swift.min(position + 1000, documents.count)])
                
                let insertMsg = Message.Insert(requestID: self.database.server.nextMessageID(), flags: [], collection: self.collection, documents: commandDocuments)
                _ = try self.database.server.send(message: insertMsg, overConnection: newConnection)
            }
        }
        
        guard errors.count == 0 else {
            throw throwErrors()
        }
        
        return newIds
    }
    
    /// Applies a pipeline over a collection's contentrs
    ///
    /// - parameter pipeline: The pipeline to use
    /// - parameter readConcern: The read concern to use on the server
    /// - parameter collation: The collation to use for string comparison
    /// - parameter options: The aggregation options to use
    /// - parameter connection: The connection to use
    /// - parameter timeout: The timeout to wait for
    func aggregate(_ pipeline: AggregationPipeline, readConcern: ReadConcern?, collation: Collation?, options: [AggregationOptions], connection: Connection?, timeout: DispatchTimeInterval?) throws -> Cursor<Document> {
        // construct command. we always use cursors in MongoKitten, so that's why the default value for cursorOptions is an empty document.
        var command: Document = ["aggregate": self.collectionName, "pipeline": pipeline.pipelineDocument, "cursor": ["batchSize": 100]]
        
        command["readConcern"] = readConcern ?? self.readConcern
        command["collation"] = collation ?? self.collation
        
        for option in options {
            for (key, value) in option.fields {
                command[key] = value
            }
        }
        
        if let listener = database.server.whenExplaining {
            listener(try collection.explained.aggregate(pipeline, readConcern: readConcern, collation: collation, options: options))
        }
        
        let reply: ServerReply
        let newConnection: Connection
        
        if let connection = connection {
            newConnection = connection
        } else {
            newConnection = try self.database.server.reserveConnection(writing: true, authenticatedFor: self.database)
        }
        
        // execute and construct cursor
        reply = try self.database.execute(command: command, using: newConnection)
        
        guard let cursorDoc = Document(reply.documents.first?["cursor"]) else {
            if connection == nil {
                self.database.server.returnConnection(newConnection)
            }
            
            throw MongoError.invalidResponse(documents: reply.documents)
        }
        
        do {
            return try Cursor(cursorDocument: cursorDoc, collection: self.collection, connection: newConnection, chunkSize: Int32(command["cursor"]["batchSize"]) ?? 100, transform: { $0 })
        } catch {
            if connection == nil {
                self.database.server.returnConnection(newConnection)
            }
            
            throw error
        }
    }
    
    func count(filter: Query?, limit: Int?, skip: Int?, readConcern: ReadConcern?, collation: Collation?, connection: Connection?, timeout: DispatchTimeInterval?) throws -> Int {
        var command: Document = ["count": self.collectionName]
        
        if let filter = filter {
            command["query"] = filter
        }
        
        if let skip = skip {
            command["skip"] = Int32(skip)
        }
        
        if let limit = limit {
            command["limit"] = Int32(limit)
        }
        
        command["readConcern"] = readConcern ?? self.readConcern
        command["collation"] = collation ?? self.collation
        
        if let listener = database.server.whenExplaining {
            listener(try collection.explained.count(filter, limiting: limit, skipping: skip, readConcern: readConcern, collation: collation, timeout: timeout))
        }
        
        let reply: ServerReply
        
        if let connection = connection {
            reply = try self.database.execute(command: command, writing: false, using: connection)
        } else {
            reply = try self.database.execute(command: command, writing: false)
        }
        
        guard let n = Int(reply.documents.first?["n"]), Int(reply.documents.first?["ok"]) == 1 else {
            throw InternalMongoError.incorrectReply(reply: reply)
        }
        
        return n
    }
    
    func update(updates: [(filter: Query, to: Document, upserting: Bool, multiple: Bool)], writeConcern: WriteConcern?, ordered: Bool?, connection: Connection?, timeout: DispatchTimeInterval?) throws -> Int {
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        
        if protocolVersion >= 2 {
            var command: Document = ["update": self.collectionName]
            var newUpdates = [Document]()
            
            for u in updates {
                newUpdates.append([
                    "q": u.filter.queryDocument,
                    "u": u.to,
                    "upsert": u.upserting,
                    "multi": u.multiple
                    ])
            }
            
            command["updates"] = Document(array: newUpdates)
            
            if let ordered = ordered {
                command["ordered"] = ordered
            }
            
            command["writeConcern"] = writeConcern ??  self.writeConcern
            
            let reply: ServerReply
            
            if let connection = connection {
                reply = try self.database.execute(command: command, writing: false, using: connection)
            } else {
                reply = try self.database.execute(command: command, writing: false)
            }
            
            if let listener = database.server.whenExplaining {
                listener(try collection.explained.update(updates: updates, writeConcern: writeConcern, ordered: ordered, timeout: timeout))
            }
            
            if let writeErrors = Document(reply.documents.first?["writeErrors"]), (Int(reply.documents.first?["ok"]) != 1 || ordered == true) {
                let writeErrors = try writeErrors.arrayValue.flatMap { value -> UpdateError.WriteError in
                    guard let document = Document(value),
                        let index = Int(document["index"]),
                        let code = Int(document["code"]),
                        let message = String(document["errmsg"]),
                        index < updates.count else {
                            throw MongoError.invalidReply
                    }
                    
                    let affectedUpdate = updates[index]
                    
                    return UpdateError.WriteError(index: index, code: code, message: message, affectedQuery: affectedUpdate.filter, affectedUpdate: affectedUpdate.to, upserting: affectedUpdate.upserting, multiple: affectedUpdate.multiple)
                }
                
                throw UpdateError(writeErrors: writeErrors)
            }
            
            return Int(reply.documents.first?["nModified"]) ?? 0
        } else {
            var newConnection: Connection
            
            if let connection = connection {
                newConnection = connection
            } else {
                newConnection = try self.database.server.reserveConnection(writing: true, authenticatedFor: self.database)
            }
            
            defer {
                if connection == nil {
                    self.database.server.returnConnection(newConnection)
                }
            }
            
            for update in updates {
                var flags: UpdateFlags = []
                
                if update.multiple {
                    flags.insert(UpdateFlags.MultiUpdate)
                }
                
                if update.upserting {
                    flags.insert(UpdateFlags.Upsert)
                }
                
                let message = Message.Update(requestID: self.database.server.nextMessageID(), collection: self.collection, flags: flags, findDocument: update.filter.queryDocument, replaceDocument: update.to)
                try self.database.server.send(message: message, overConnection: newConnection)
                // TODO: Check for errors
            }
            
            return updates.count
        }
    }
    
    func remove(removals: [(filter: Query, limit: Int)], writeConcern: WriteConcern?, ordered: Bool?, connection: Connection?, timeout: DispatchTimeInterval?) throws -> Int {
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        
        if protocolVersion >= 2 {
            var command: Document = ["delete": self.collectionName]
            var newDeletes = [Document]()
            
            for d in removals {
                newDeletes.append([
                    "q": d.filter.queryDocument,
                    "limit": d.limit
                    ])
            }
            
            command["deletes"] = Document(array: newDeletes)
            
            if let ordered = ordered {
                command["ordered"] = ordered
            }
            
            command["writeConcern"] = writeConcern ?? self.writeConcern
            
            let reply: ServerReply
            
            if let connection = connection {
                reply = try self.database.execute(command: command, writing: false, using: connection)
            } else {
                reply = try self.database.execute(command: command, writing: false)
            }
            
            if let listener = database.server.whenExplaining {
                listener(try collection.explained.remove(removals: removals, writeConcern: writeConcern, ordered: ordered, timeout: timeout))
            }
            
            if let writeErrors = Document(reply.documents.first?["writeErrors"]), (Int(reply.documents.first?["ok"]) != 1 || ordered == true) {
                let writeErrors = try writeErrors.arrayValue.flatMap { value -> RemoveError.WriteError in
                    guard let document = Document(value),
                        let index = Int(document["index"]),
                        let code = Int(document["code"]),
                        let message = String(document["errmsg"]),
                        index < removals.count else {
                            throw MongoError.invalidReply
                    }
                    
                    let affectedRemove = removals[index]
                    
                    return RemoveError.WriteError(index: index, code: code, message: message, affectedQuery: affectedRemove.filter, limit: affectedRemove.limit)
                }
                
                throw RemoveError(writeErrors: writeErrors)
            }
            
            return Int(reply.documents.first?["n"]) ?? 0
            
            // If we're communicating with an older MongoDB server
        } else {
            var newConnection: Connection
            
            if let connection = connection {
                newConnection = connection
            } else {
                newConnection = try self.database.server.reserveConnection(writing: true, authenticatedFor: self.database)
            }
            
            defer {
                if connection == nil {
                    self.database.server.returnConnection(newConnection)
                }
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
                
                let message = Message.Delete(requestID: self.database.server.nextMessageID(), collection: self.collection, flags: flags, removeDocument: removal.filter.queryDocument)
                
                for _ in 0..<limit {
                    try self.database.server.send(message: message, overConnection: newConnection)
                }
            }
            
            return removals.count
        }
    }
    
    func find(filter: Query?, sort: Sort?, projection: Projection?, readConcern: ReadConcern?, collation: Collation?, skip: Int?, limit: Int?, batchSize: Int = 100, connection: Connection?) throws -> CollectionSlice<Document> {
        if self.collection.database.server.buildInfo.version >= Version(3,2,0) {
            var command: Document = [
                "find": collection.name,
                "readConcern": readConcern ?? collection.readConcern,
                "collation": collation ?? collection.collation,
                "batchSize": Int32(batchSize)
            ]
            
            if let filter = filter {
                command["filter"] = filter
            }
            
            if let sort = sort {
                command["sort"] = sort
            }
            
            if let projection = projection {
                command["projection"] = projection
            }
            
            if let skip = skip {
                command["skip"] = Int32(skip)
            }
            
            if let limit = limit {
                command["limit"] = Int32(limit)
            }
            
            if let listener = database.server.whenExplaining {
                listener(try collection.explained.find(filter, sortedBy: sort, projecting: projection, readConcern: readConcern, collation: collation, skipping: skip, limitedTo: limit, withBatchSize: batchSize))
            }
            
            let cursorConnection = try connection ?? (try self.database.server.reserveConnection(authenticatedFor: self.collection.database))
            
            let reply = try self.database.execute(command: command, until: 30, writing: false, using: cursorConnection)
            
            guard let responseDoc = reply.documents.first, let cursorDoc = Document(responseDoc["cursor"]) else {
                if connection == nil {
                    self.database.server.returnConnection(cursorConnection)
                }
                
                throw MongoError.invalidResponse(documents: reply.documents)
            }
            
            let cursor = try Cursor(cursorDocument: cursorDoc, collection: self.collection, connection: cursorConnection, chunkSize: Int32(batchSize), transform: { doc in
                return doc
            })
            
            return CollectionSlice(cursor: cursor, filter: filter, sort: sort, projection: projection, skip: skip, limit: limit)
        } else {
            let queryMsg = Message.Query(requestID: collection.database.server.nextMessageID(), flags: [], collection: collection, numbersToSkip: Int32(skip) ?? 0, numbersToReturn: Int32(batchSize), query: filter?.queryDocument ?? [], returnFields: projection?.document)
            
            let cursorConnection = try connection ?? (try self.database.server.reserveConnection(authenticatedFor: self.collection.database))
            
            var reply = try self.database.server.sendAndAwait(message: queryMsg, overConnection: cursorConnection)
            
            if let limit = limit {
                if reply.documents.count > Int(limit) {
                    reply.documents.removeLast(reply.documents.count - Int(limit))
                }
            }
            
            var returned: Int = 0
            
            let cursor = Cursor(namespace: self.fullCollectionName, collection: self.collection, connection: cursorConnection, cursorID: reply.cursorID, initialData: reply.documents, chunkSize: Int32(batchSize), transform: { doc in
                if let limit = limit {
                    guard returned < limit else {
                        return nil
                    }
                    
                    returned += 1
                }
                return doc
            })
            
            return CollectionSlice(cursor: cursor, filter: filter, sort: sort, projection: projection, skip: skip, limit: limit)
        }
    }
}
