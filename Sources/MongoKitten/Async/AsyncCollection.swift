//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//
import Dispatch
import Schrodinger

extension Collection {
    /// Returns this collection's async API
    public var async: AsyncCollection {
        return self.database[async: self.name]
    }
}

/// Represents a single MongoDB collection with an asynchronous API.
///
/// **### Definition ###**
///
/// A grouping of MongoDB documents. A collection is the equivalent of an RDBMS table. A collection exists within a single database. Collections do not enforce a schema. Documents within a collection can have different fields. Typically, all documents in a collection have a similar or related purpose. See Namespaces.
public final class AsyncCollection : CollectionQueryable {
    public var fullName: String {
        return "\(database.name).\(name)"
    }
    
    public let name: String
    
    public let database: Database
    
    public var readConcern: ReadConcern?
    
    public var writeConcern: WriteConcern?
    
    public var collation: Collation?
    
    public var timeout: DispatchTimeInterval?
    
    init(named name: String, in database: Database) {
        self.database = database
        self.name = name
    }
    
    @discardableResult
    public func insert(_ document: Document, stoppingOnError ordered: Bool? = nil, writeConcern: WriteConcern? = nil, timingOut afterTimeout: DispatchTimeInterval? = nil) throws -> Future<BSON.Primitive> {
        return try self.insert(documents: [document], ordered: ordered, writeConcern: writeConcern, timeout: afterTimeout, connection: nil).map { result in
            guard let newId = result.first else {
                log.error("No identifier could be generated")
                throw MongoError.internalInconsistency
            }
            
            return newId
        }
    }
    
    @discardableResult
    public func insert(contentsOf documents: [Document], stoppingOnError ordered: Bool? = nil, writeConcern: WriteConcern? = nil, timingOut afterTimeout: DispatchTimeInterval? = nil) throws -> Future<[BSON.Primitive]> {
        return try self.insert(documents: documents, ordered: ordered, writeConcern: writeConcern, timeout: afterTimeout, connection: nil)
    }
    
    public func findOne(_ query: Query? = nil, sortedBy sort: Sort? = nil, projecting projection: Projection? = nil, skipping skip: Int? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil) throws -> Future<Document?> {
        return try self.find(filter: query, sort: sort, projection: projection, readConcern: readConcern, collation: collation, skip: skip, limit: 1, timeout: nil, connection: nil).map { documents in
            return documents.next()
        }
    }
    
    public func find(_ filter: Query? = nil, sortedBy sort: Sort? = nil, projecting projection: Projection? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, skipping skip: Int? = nil, limitedTo limit: Int? = nil, withBatchSize batchSize: Int = 100) throws -> Future<Cursor<Document>> {
        precondition(batchSize < Int(Int32.max))
        precondition(skip ?? 0 < Int(Int32.max))
        precondition(limit ?? 0 < Int(Int32.max))
        
        return try self.find(filter: filter, sort: sort, projection: projection, readConcern: readConcern, collation: collation, skip: skip, limit: limit, batchSize: batchSize, timeout: nil, connection: nil)
    }
    
    @discardableResult
    public func update(bulk updates: [(filter: Query, to: Document, upserting: Bool, multiple: Bool)], writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Future<Int> {
        return try update(updates: updates, writeConcern: writeConcern, ordered: ordered, connection: nil, timeout: nil)
    }
    
    @discardableResult
    public func update(_ filter: Query = [:], to updated: Document, upserting upsert: Bool = false, multiple multi: Bool = false, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Future<Int> {
        return try self.update(bulk: [(filter: filter, to: updated, upserting: upsert, multiple: multi)], writeConcern: writeConcern, stoppingOnError: ordered)
    }
    
    @discardableResult
    public func remove(bulk removals: [(filter: Query, limit: RemoveLimit)], writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Future<Int> {
        return try self.remove(removals: removals, writeConcern: writeConcern, ordered: ordered, connection: nil, timeout: nil)
    }
    
    @discardableResult
    public func remove(_ filter: Query? = [:], limitedTo limit: RemoveLimit = .all, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Future<Int> {
        return try self.remove(bulk: [(filter: filter ?? [:], limit: limit)], writeConcern: writeConcern, stoppingOnError: ordered)
    }
    
    public func count(_ filter: Query? = nil, limitedTo limit: Int? = nil, skipping skip: Int? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil) throws -> Future<Int> {
        return try self.count(filter: filter, limit: limit, skip: skip, readConcern: readConcern, collation: collation, connection: nil, timeout: nil)
    }
}

extension Future {
    func await() throws -> T {
        return try self.await(for: .seconds(60))
    }
}
