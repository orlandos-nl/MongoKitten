//
//  File.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 08/03/2017.
//
//

import Dispatch
import BSON
import Schrodinger

/// Makes it internally queryable
protocol CollectionQueryable {
    /// The full collection name. Created by adding the Database's name with the Collection's name with a dot to seperate them
    var fullName: String { get }
    
    /// The short collection name
    var name: String { get }
    
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
    /// Inserts a set of Documents
    ///
    /// - parameter documents: The documents to insert
    /// - parameter ordered: When true, stops inserting when an error occurs
    /// - parameter writeConcern: The write concern to use on the server
    /// - parameter timeout: The timeout to wait for
    /// - parameter connection: The connection to use
    ///
    /// - throws: An `InsertError` when a write error occurs
    func insert(documents: [Document], ordered: Bool?, writeConcern: WriteConcern?, timeout: DispatchTimeInterval?, connection: Connection?) throws -> Future<[BSON.Primitive]> {
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
        
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        var position = 0
        
        let newConnection: Connection
        
        // Reuse an existing connection if provided
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
        
        // Return the async response, spawn a loose thread for handling
        let response = Future<[BSON.Primitive]>()
        
        var promises = [Future<Void>]()
        
        // Insert 1000 documents at a time
        while position < documents.count {
            defer { position += 1000 }
            
            // For protocol >= 2, use the DB command
            if protocolVersion >= 2 {
                var command: Document = ["insert": self.name]
                
                command["documents"] = Document(array: Array(documents[position..<Swift.min(position + 1000, documents.count)]))
                
                if let ordered = ordered {
                    command["ordered"] = ordered
                }
                
                command["writeConcern"] = writeConcern ?? self.writeConcern
                
                // Insert the new entities
                let result = try self.database.execute(command: command, using: newConnection).map { reply in
                    var errors = Array<InsertErrors.InsertError>()
                    
                    // Groups all errors into a struct
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
                    
                    // Checks for errors
                    if let writeErrors = Document(reply.documents.first?["writeErrors"]) {
                        // If there are errors
                        guard let documents = Document(command["documents"]) else {
                            throw MongoError.invalidReply
                        }
                        
                        // Deserialize the errors
                        let writeErrors = try writeErrors.arrayRepresentation.flatMap { value -> InsertErrors.InsertError.WriteError in
                            guard let document = Document(value),
                                let index = Int(document["index"]),
                                let code = Int(document["code"]),
                                let message = String(document["errmsg"]),
                                index < documents.count,
                                let affectedDocument = Document(documents[index]) else {
                                    throw MongoError.invalidReply
                            }
                            
                            // Add them to the array
                            return InsertErrors.InsertError.WriteError(index: index, code: code, message: message, affectedDocument: affectedDocument)
                        }
                        
                        errors.append(InsertErrors.InsertError(writeErrors: writeErrors))
                    }
                    
                    guard Int(reply.documents.first?["ok"]) == 1 else {
                        throw throwErrors()
                    }
                    
                    if ordered == true {
                        guard errors.count == 0 else {
                            throw throwErrors()
                        }
                    }
                }
                
                promises.append(result)
                
            // < protocol version 2, use the separate insert operation
            } else {
                let future = Future<Void> {
                    let commandDocuments = Array(documents[position..<Swift.min(position + 1000, documents.count)])
                    
                    let insertMsg = Message.Insert(requestID: self.database.server.nextMessageID(), flags: [], collection: self.fullName, documents: commandDocuments)
                    _ = try self.database.server.send(message: insertMsg, overConnection: newConnection)
                }
                
                promises.append(future)
            }
        }
        
        promises.then { results in
            _ = try? response.complete {
                try results.assertSuccess()
                return newIds
            }
        }
        
        return response
    }
    
    func update(updates: [(filter: Query, to: Document, upserting: Bool, multiple: Bool)], writeConcern: WriteConcern?, ordered: Bool?, connection: Connection?, timeout: DispatchTimeInterval?) throws -> Future<Int> {
        let timeout: DispatchTimeInterval = timeout ?? .seconds(Int(database.server.defaultTimeout))
        
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        
        if protocolVersion >= 2 {
            var command: Document = ["update": self.name]
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
            
            let reply: Future<ServerReply>
            
            if let connection = connection {
                reply = try self.database.execute(command: command, writing: false, using: connection)
            } else {
                reply = try self.database.execute(command: command, writing: false)
            }
            
            return reply.map { reply in
                if let writeErrors = Document(reply.documents.first?["writeErrors"]), (Int(reply.documents.first?["ok"]) != 1 || ordered == true) {
                    let writeErrors = try writeErrors.arrayRepresentation.flatMap { value -> UpdateError.WriteError in
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
                
                guard Int(reply.documents.first?["ok"]) == 1 else {
                    throw MongoError.invalidResponse(documents:reply.documents)
                }
                    
                return Int(reply.documents.first?["nModified"]) ?? 0
            }
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
            
            return Future {
                for update in updates {
                    var flags: UpdateFlags = []
                    
                    if update.multiple {
                        flags.insert(UpdateFlags.MultiUpdate)
                    }
                    
                    if update.upserting {
                        flags.insert(UpdateFlags.Upsert)
                    }
                    
                    let message = Message.Update(requestID: self.database.server.nextMessageID(), collection: self.fullName, flags: flags, findDocument: update.filter.queryDocument, replaceDocument: update.to)
                    try self.database.server.send(message: message, overConnection: newConnection)
                    // TODO: Check for errors
                }
                
                return updates.count
            }
        }
    }
    
    func remove(removals: [(filter: Query, limit: RemoveLimit)], writeConcern: WriteConcern?, ordered: Bool?, connection: Connection?, timeout: DispatchTimeInterval?) throws -> Future<Int> {
        let timeout: DispatchTimeInterval = timeout ?? .seconds(Int(database.server.defaultTimeout))
        
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        
        if protocolVersion >= 2 {
            var command: Document = ["delete": self.name]
            var newDeletes = [Document]()
            
            for d in removals {
                newDeletes.append([
                    "q": d.filter.queryDocument,
                    "limit": d.limit.rawValue
                    ])
            }
            
            command["deletes"] = Document(array: newDeletes)
            
            if let ordered = ordered {
                command["ordered"] = ordered
            }
            
            command["writeConcern"] = writeConcern ?? self.writeConcern
            
            let reply: Future<ServerReply>
            
            if let connection = connection {
                reply = try self.database.execute(command: command, writing: false, using: connection)
            } else {
                reply = try self.database.execute(command: command, writing: false)
            }
            
            return reply.map { reply in
                if let writeErrors = Document(reply.documents.first?["writeErrors"]), (Int(reply.documents.first?["ok"]) != 1 || ordered == true) {
                    let writeErrors = try writeErrors.arrayRepresentation.flatMap { value -> RemoveError.WriteError in
                        guard let document = Document(value),
                            let index = Int(document["index"]),
                            let code = Int(document["code"]),
                            let message = String(document["errmsg"]),
                            index < removals.count else {
                                throw MongoError.invalidReply
                        }
                        
                        let affectedRemove = removals[index]
                        
                        return RemoveError.WriteError(index: index, code: code, message: message, affectedQuery: affectedRemove.filter, limit: affectedRemove.limit.rawValue)
                    }
                    
                    throw RemoveError(writeErrors: writeErrors)
                }
                
                guard Int(reply.documents.first?["ok"]) == 1 else {
                    throw MongoError.invalidResponse(documents:reply.documents)
                }
                    
                return Int(reply.documents.first?["n"]) ?? 0
            }
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
            
            return Future {
                for removal in removals {
                    var flags: DeleteFlags = []
                    
                    // If the limit is not '0' and thus removes a set amount of documents. Set it to RemoveOne so we'll remove one document at a time using the older method
                    if removal.limit == .one {
                        flags.insert(DeleteFlags.RemoveOne)
                    }
                    
                    let message = Message.Delete(requestID: self.database.server.nextMessageID(), collection: self.fullName, flags: flags, removeDocument: removal.filter.queryDocument)
                    
                    try self.database.server.send(message: message, overConnection: newConnection)
                }
                
                return removals.count
            }
        }
    }
}
