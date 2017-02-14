//
//  DeleteRequest.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 14/02/2017.
//
//

import Foundation

public struct RemoveResponse : DatabaseResponse {
    public let removeCount: Int
    public let collection: MongoCollection
}

public struct RemoveRequest : WriteDatabaseRequest {
    public var removals: [RemoveQuery]
    
    public struct RemoveQuery {
        var filter: Query
        var limit: Int
    }
    
    public var ordered: Bool? = nil
    public var writeConcern: WriteConcern?
    public let collection: MongoCollection
    
    public func execute() throws -> RemoveResponse {
        let protocolVersion = collection.database.server.serverData?.maxWireVersion ?? 0
        
        if collection.database.server.buildInfo.version >= Version(2,6,0) {
            var command: Document = ["delete": collection.name]
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
            
            let reply = try collection.database.execute(command: command)
            let documents = try allDocuments(in: reply)
            
            guard let document = documents.first, document["ok"] as Int? == 1 else {
                throw MongoError.removeFailure(removals: removals, error: documents.first)
            }
            
            guard let removed = document["n"] as Int? else {
                throw MongoError.removeFailure(removals: removals, error: documents.first)
            }
            
            return RemoveResponse(removeCount: removed, collection: collection)
            
            // If we're talking to an older MongoDB server
        } else {
            let connection = try collection.database.server.reserveConnection(authenticatedFor: collection.database)
            
            defer {
                collection.database.server.returnConnection(connection)
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
                
                let message = Message.Delete(requestID: collection.database.server.nextMessageID(), collection: collection, flags: flags, removeDocument: removal.filter.queryDocument)
                
                for _ in 0..<limit {
                    try collection.database.server.send(message: message, overConnection: connection)
                }
            }
            
            return RemoveResponse(removeCount: removals.count, collection: collection)
        }

    }
}

public typealias RemoveHook = ((RemoveRequest) throws -> (Int))

extension Collection {
    @discardableResult
    public func remove(matching removals: [(filter: Query, limit: Int)], writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil, applying hook: RemoveHook? = nil) throws -> Int {
        let request = RemoveRequest(removals: removals.map { removal in
            return RemoveRequest.RemoveQuery(filter: removal.filter, limit: removal.limit)
        }, ordered: ordered, writeConcern: writeConcern, collection: self)
        
        let hook = hook ?? self.removeHook ?? DefaultHook.removeHook
        
        return try hook(request)
    }
    
    @discardableResult
    public func remove(matching filter: Query, limitedTo limit: Int = 0, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil, applying hook: RemoveHook? = nil) throws -> Int {
        return try self.remove(matching: [(filter: filter, limit: limit)], writeConcern: writeConcern, stoppingOnError: ordered, applying: hook)
    }
}
