import BSON

public struct UpdateResponse : DatabaseResponse {
    public let updateCount: Int
    public let collection: MongoCollection
}

public struct UpdateRequest : WriteDatabaseRequest {
    public var updates: [UpdateQuery]
    public var ordered: Bool?
    public var writeConcern: WriteConcern?
    public let collection: MongoCollection
    
    public struct UpdateQuery {
        var filter: Query
        var to: Document
        var upserting: Bool
        var multiple: Bool
    }
    
    public func execute() throws -> UpdateResponse {
        if collection.database.server.buildInfo.version >= Version(2,6,0) {
            var command: Document = ["update": collection.name]
            var newUpdates = [] as Document
            
            for update in updates {
                newUpdates.append([
                    "q": update.filter.queryDocument,
                    "u": update.to,
                    "upsert": update.upserting,
                    "multi": update.multiple
                    ] as Document)
            }
            
            command["updates"] = newUpdates
            
            if let ordered = ordered {
                command["ordered"] = ordered
            }
            
            command[raw: "writeConcern"] = writeConcern ??  self.writeConcern
            
            let reply = try collection.database.execute(command: command)
            guard case .Reply(_, _, _, _, _, _, let documents) = reply else {
                throw MongoError.updateFailure(updates: updates, error: nil)
            }
            
            guard documents.first?["ok"] as Int? == 1 && (documents.first?["writeErrors"] as Document? ?? [:]).count == 0 else {
                throw MongoError.updateFailure(updates: updates, error: documents.first)
            }
            
            guard let modified = documents.first?["nModified"] as Int? else {
                throw MongoError.updateFailure(updates: updates, error: documents.first)
            }
            
            return UpdateResponse(updateCount: modified, collection: collection)
        } else {
            let connection = try collection.database.server.reserveConnection(writing: true, authenticatedFor: collection.database)
            
            defer {
                collection.database.server.returnConnection(connection)
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
                
                let message = Message.Update(requestID: collection.database.server.nextMessageID(), collection: collection, flags: flags, findDocument: update.filter.queryDocument, replaceDocument: update.to)
                try collection.database.server.send(message: message, overConnection: connection)
                // TODO: Check for errors
            }
            
            return UpdateResponse(updateCount: updates.count, collection: collection)
        }
    }
}

public typealias UpdateHook = ((UpdateRequest) throws -> (Int))

extension Collection {
    @discardableResult
    public func update(matching filter: Query = [:], to updated: Document, upserting upsert: Bool = false, multiple multi: Bool = false, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil, applying hook: UpdateHook? = nil) throws -> Int {
        return try self.update([(filter: filter, to: updated, upserting: upsert, multiple: multi)], writeConcern: writeConcern, stoppingOnError: ordered, applying: hook)
    }
    
    @discardableResult
    public func update(_ updates: [(filter: Query, to: Document, upserting: Bool, multiple: Bool)], writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil, applying hook: UpdateHook? = nil) throws -> Int {
        let request = UpdateRequest(updates: updates.map { update in
            return UpdateRequest.UpdateQuery(filter: update.filter, to: update.to, upserting: update.upserting, multiple: update.multiple)
        }, ordered: ordered, writeConcern: writeConcern, collection: self)
        
        let hook = hook ?? self.updateHook ?? DefaultHook.updateHook
        
        return try hook(request)
    }
}
