//
//  Database.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 27/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation

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
}