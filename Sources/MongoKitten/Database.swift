//
//  Database.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 24-05-18.
//

import Foundation
import NIO

public class Database {
    
    public static func connect(_ uri: String) -> EventLoopFuture<Database> {
        unimplemented()
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
