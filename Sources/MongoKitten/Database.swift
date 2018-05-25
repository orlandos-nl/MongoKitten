//
//  Database.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 24-05-18.
//

import Foundation
import NIO

public final class Database {
    public let name: String
    public let connection: MongoDBConnection
    
    public static func connect(_ uri: String) -> EventLoopFuture<Database> {
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
    public subscript(collection: String) -> MongoKitten.Collection {
        return Collection(named: collection, in: self)
    }
    
}
