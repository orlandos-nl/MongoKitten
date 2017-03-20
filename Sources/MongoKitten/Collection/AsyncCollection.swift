//
//  AsyncCollection.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 05/03/2017.
//
//

import Foundation
import Dispatch
import Schrodinger

/// Represents a single MongoDB collection.
///
/// **### Definition ###**
///
/// A grouping of MongoDB documents. A collection is the equivalent of an RDBMS table. A collection exists within a single database. Collections do not enforce a schema. Documents within a collection can have different fields. Typically, all documents in a collection have a similar or related purpose. See Namespaces.
///
/// This AsyncCollection differs from a normal Collection in that the exposed APIs are asynchronous by nature
public class AsyncCollection {
    /// The Database this collection is in
    public private(set) var database: Database
    
    // The synchronous collection
    public private(set) var syncCollection: Collection
    
    /// The collection name
    public private(set) var name: String
    
    /// The full (computed) collection name. Created by adding the Database's name with the Collection's name with a dot to seperate them
    /// Will be empty
    public var fullName: String {
        return "\(database.name).\(name)"
    }
    
    /// The default ReadConcern for this Collection
    private var defaultReadConcern: ReadConcern? = nil
    
    /// Sets or gets the default read concern at the collection level. If the default read concern is not set, it will return the default read concern for the database instead.
    public var readConcern: ReadConcern? {
        get {
            return self.defaultReadConcern ?? database.readConcern
        }
        set {
            self.defaultReadConcern = newValue
        }
    }
    
    /// The default WriteConcern for this Collection
    private var defaultWriteConcern: WriteConcern? = nil
    
    /// Sets or gets the default write concern at the collection level. If the default write concern is not set, it will return the default write concern for the database instead.
    public var writeConcern: WriteConcern? {
        get {
            return self.defaultWriteConcern ?? database.writeConcern
        }
        set {
            self.defaultWriteConcern = newValue
        }
    }
    
    /// The default Collation for collections in this Collection
    private var defaultCollation: Collation? = nil
    
    /// Sets or gets the default read concern at the collection level. If the default collation is not set, it will return the default collation for the database instead.
    public var collation: Collation? {
        get {
            return self.defaultCollation ?? database.collation
        }
        set {
            self.defaultCollation = newValue
        }
    }
    
    /// Initializes this asynchronous collection with a database and name
    ///
    /// - parameter name: The collection name
    /// - parameter database: The database this `Collection` exists in
    internal init(named name: String, in database: Database) {
        self.database = database
        self.name = name
        self.syncCollection = database[name]
    }
    
    public func append(_ insertDocument: Document) throws -> Promise<Void> {
        return async {
            try self.syncCollection.insert(insertDocument)
        }
    }
    
    public func insert(_ document: Document, stoppingOnError ordered: Bool? = nil, writeConcern: WriteConcern? = nil, timingOut afterTimeout: TimeInterval? = nil) throws -> Promise<BSON.Primitive> {
        return async {
            return try self.syncCollection.insert(document)
        }
    }
    
    public func append(contentsOf documents: [Document]) throws -> Promise<Void> {
        return async {
            try self.syncCollection.append(contentsOf: documents)
        }
    }
    
    public func insert(contentsOf documents: [Document], stoppingOnError ordered: Bool? = nil, writeConcern: WriteConcern? = nil, timingOut afterTimeout: DispatchTimeInterval? = nil) throws -> Promise<[BSON.Primitive]> {
        return async {
            return try self.syncCollection.insert(contentsOf: documents, stoppingOnError: ordered, writeConcern: writeConcern, timingOut: afterTimeout)
        }
    }
}
