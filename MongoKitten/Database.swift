//
//  Database.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 27/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation

public class Database {
    let server: Server
    let name: String
    internal var collections = [String:Collection]()
    
    public init(server: Server, databaseName name: String) throws {
        let name = name.stringByReplacingOccurrencesOfString(".", withString: "")
        
        self.server = server
        
        if name.characters.count <= 0 {
            self.name = ""
            throw MongoError.InvalidDatabaseName
        }
        
        self.name = name
    }
    
    public subscript (collection: String) -> Collection {
        if let collection: Collection = collections[collection] {
            return collection
        }
        
        let collection = collection.stringByReplacingOccurrencesOfString(".", withString: "")
        
        if collection.isEmpty {
            print("Trying to access empty collection")
            abort()
        }
        
        let collectionObject = try! Collection(database: self, collectionName: collection)
        
        collections[collection] = collectionObject
        
        return collectionObject
    }
}