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
    
    func remove(removals: [(filter: Query, limit: RemoveLimit)], writeConcern: WriteConcern?, ordered: Bool?, connection: Connection?, timeout: DispatchTimeInterval?) throws -> Future<Int> {
        let timeout: DispatchTimeInterval = timeout ?? .seconds(Int(database.server.defaultTimeout))
        
        let protocolVersion = database.server.serverData?.maxWireVersion ?? 0
        
        if protocolVersion >= 2 {
            var command: Document = ["delete": self.name]
            var newDeletes = [Document]()
            
            for d in removals {
                newDeletes.append([
                    "q": d.filter.document,
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
