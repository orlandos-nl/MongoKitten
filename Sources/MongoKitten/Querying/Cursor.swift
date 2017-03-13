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

public typealias BasicCursor = Cursor<Document>

public class Cursor<T> : CollectionQueryable {
    var timeout: DispatchTimeInterval?

    public let collection: Collection
    
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
    
    public var filter: Query?
    
    public typealias Transformer = (Document) throws -> (T?)
    
    public let transform: Transformer
    
    public func count(limiting limit: Int? = nil, skipping skip: Int? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, timingOut afterTimeout: DispatchTimeInterval? = nil) throws -> Int {
        return try self.count(filter: filter, limit: limit, skip: skip, readConcern: readConcern, collation: collation, connection: nil, timeout: afterTimeout).await()
    }
    
    public func findOne(sorting sort: Sort? = nil, projecting projection: Projection? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, skipping skip: Int? = nil) throws -> T? {
        return try self.find(sorting: sort, projecting: projection, readConcern: readConcern, collation: collation, skipping: skip, limitedTo: 1, withBatchSize: 1).next()
    }
    
    public var first: T? {
        do {
            return try findOne()
        } catch {
            return nil
        }
    }
    
    public func find(sorting sort: Sort? = nil, projecting projection: Projection? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, skipping skip: Int? = nil, limitedTo limit: Int? = nil, withBatchSize batchSize: Int = 100) throws -> AnyIterator<T> {
        let cursor = try self.find(filter: filter, sort: sort, projection: projection, readConcern: readConcern, collation: collation, skip: skip, limit: limit, connection: nil).await()
        
        return try _Cursor(base: cursor, transform: transform).makeIterator()
    }
    
    public func update(to document: Document, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        return try self.update(updates: [(filter ?? [:], document, false, true)], writeConcern: writeConcern, ordered: ordered, connection: nil, timeout: nil).await()
    }
    
    @discardableResult
    public func remove(limiting limit: Int = 0, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        return try collection.remove(filter ?? [:], limiting: limit, writeConcern: writeConcern, stoppingOnError: ordered)
    }
    
    public func flatMap<B>(transform: @escaping (T) throws -> (B?)) -> Cursor<B> {
        return Cursor<B>(base: self, transform: transform)
    }
    
    public init<B>(base: Cursor<B>, transform: @escaping (B) throws -> (T?)) {
        self.collection = base.collection
        self.filter = base.filter
        self.transform = {
            if let bValue = try base.transform($0) {
                return try transform(bValue)
            } else {
                return nil
            }
        }
    }
    
    public init(`in` collection: Collection, `where` filter: Query? = nil, transform: @escaping Transformer) {
        self.collection = collection
        self.filter = filter
        self.transform = transform
    }
}

extension Cursor where T == Document {
    public convenience init(`in` collection: Collection, `where` filter: Query? = nil) {
        self.init(in: collection, where: filter) { $0 }
    }
}
