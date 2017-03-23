//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//
import BSON
import Dispatch
import Schrodinger

public class CollectionSlice<Element> : CollectionQueryable, Sequence, IteratorProtocol {
    var timeout: DispatchTimeInterval?
    
    internal var collection: Collection {
        return cursor.collection
    }
    
    var fullCollectionName: String {
        return collection.fullName
    }
    
    var collectionName: String {
        return collection.name
    }
    
    var database: Database {
        return collection.database
    }
    
    var readConcern: ReadConcern? {
        get {
            return collection.readConcern
        }
        set {
            collection.readConcern = newValue
        }
    }
    
    var writeConcern: WriteConcern? {
        get {
            return collection.writeConcern
        }
        set {
            collection.writeConcern = newValue
        }
    }
    
    var collation: Collation? {
        get {
            return collection.collation
        }
        set {
            collection.collation = newValue
        }
    }
    
    public private(set) var cursor: Cursor<Element>
    
    public func next() -> Element? {
        return cursor.next()
    }
    
    public func makeIterator() -> AnyIterator<Element> {
        return AnyIterator {
            self.cursor.next()
        }
    }
    
    public var filter: Query?
    
    public func count(limiting limit: Int? = nil, skipping skip: Int? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, timingOut afterTimeout: DispatchTimeInterval? = nil) throws -> Int {
        return try self.count(filter: filter, limit: limit, skip: skip, readConcern: readConcern, collation: collation, connection: nil, timeout: afterTimeout).await()
    }
    
    public func findOne(sorting sort: Sort? = nil, projecting projection: Projection? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, skipping skip: Int? = nil) throws -> Element? {
        return try self.find(sorting: sort, projecting: projection, readConcern: readConcern, collation: collation, skipping: skip, limitedTo: 1, withBatchSize: 1).next()
    }
    
    public var first: Element? {
        do {
            return try findOne()
        } catch {
            return nil
        }
    }
    
    public func find(sorting sort: Sort? = nil, projecting projection: Projection? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, skipping skip: Int? = nil, limitedTo limit: Int? = nil, withBatchSize batchSize: Int = 100) throws -> CollectionSlice<Element> {
        return try self.find(filter: filter, sort: sort, projection: projection, readConcern: readConcern, collation: collation, skip: skip, limit: limit, connection: nil).await().flatMap(transform: self.cursor.transform)
    }
    
    public func update(to document: Document, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        return try self.update(updates: [(filter ?? [:], document, false, true)], writeConcern: writeConcern, ordered: ordered, connection: nil, timeout: nil).await()
    }
    
    @discardableResult
    public func remove(limiting limit: Int = 0, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        return try collection.remove(filter ?? [:], limiting: limit, writeConcern: writeConcern, stoppingOnError: ordered)
    }
    
    public func flatMap<B>(transform: @escaping (Element) throws -> (B?)) throws -> CollectionSlice<B> {
        let cursor = try Cursor<B>(base: self.cursor, transform: transform)

        return CollectionSlice<B>(cursor: cursor)
    }
    
    internal init(cursor: Cursor<Element>) {
        self.cursor = cursor
    }
}
