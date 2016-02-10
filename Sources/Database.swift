//
//  Database.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 27/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation

public class Database {
    public let server: Server
    public let name: String
    internal var collections = [String:Collection]()
    
    internal init(server: Server, databaseName name: String) {
        let name = name.stringByReplacingOccurrencesOfString(".", withString: "")
        
        self.server = server
        self.name = name
    }
    
    public subscript (collection: String) -> Collection {
        let collection = collection.stringByReplacingOccurrencesOfString(".", withString: "")
        
        if let collection: Collection = collections[collection] {
            return collection
        }
        
        let collectionObject = Collection(database: self, collectionName: collection)
        
        collections[collection] = collectionObject
        
        return collectionObject
    }
}