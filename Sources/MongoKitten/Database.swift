//
//  Database.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 24-05-18.
//

import Foundation

public final class Database {
    public let name: String
    public let connection: MongoDBConnection
    
    public init(_ uri: String) {
        unimplemented()
    }
    
    internal init(named name: String, connection: MongoDBConnection) {
        self.name = name
        self.connection = connection
    }
    
    /// Get a `Collection` by providing a collection name as a `String`
    ///
    /// - parameter collection: The collection/bucket to return
    ///
    /// - returns: The requested collection in this database
    public subscript(collection: String) -> Collection {
        return Collection(named: collection, in: self)
    }
    
}
