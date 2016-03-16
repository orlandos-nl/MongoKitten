//
//  Database.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 27/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

/// A Mongo Database. Cannot be publically initialized. But you can get a database object by subscripting a Server with a String
public class Database {
    /// The server that this Database is a part of
    public let server: Server
    
    /// The database's name
    public let name: String
    
    internal init(server: Server, databaseName name: String) {
        let name = name.stringByReplacingOccurrencesOfString(".", withString: "")
        
        self.server = server
        self.name = name
    }
    
    /// This subscript is used to get a collection by providing a name as a String
    public subscript (collection: String) -> Collection {
        let collection = collection.stringByReplacingOccurrencesOfString(".", withString: "")
        
        return Collection(database: self, collectionName: collection)
    }
    
    internal func executeCommand(command: Document) throws -> ReplyMessage {
        let cmd = self["$cmd"]
        let commandMessage = try QueryMessage(collection: cmd, query: command, flags: [], numbersToReturn: 1)
        let id = try server.sendMessage(commandMessage)
        return try server.awaitResponse(id)
    }
    
    public func getCollectionInfos(filter filter: Document? = nil) throws -> Cursor<Document> {
        var request: Document = ["listCollections": 1]
        if let filter = filter {
            request["filter"] = filter
        }
        
        let reply = try executeCommand(request)
        
        guard let result = reply.documents.first, code = result["ok"]?.intValue, cursor = result["cursor"] as? Document where code == 1 else {
            throw MongoError.CommandFailure
        }
        
        return try Cursor(cursorDocument: cursor, server: server, chunkSize: 10, transform: { $0 })
    }
    
    public func getCollections(filter filter: Document? = nil) throws -> Cursor<Collection> {
        let infoCursor = try self.getCollectionInfos(filter: filter)
        return Cursor(base: infoCursor) { collectionInfo in
            guard let name = collectionInfo["name"]?.stringValue else { return nil }
            return self[name]
        }
    }
}