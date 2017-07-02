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

/// A subset of data in Collection
public class CollectionSlice<Element> : CollectionQueryable, Sequence, IteratorProtocol {
    /// The timeout to apply on operations
    var timeout: DispatchTimeInterval?
    
    /// The collection being sliced
    internal var collection: Collection {
        return cursor.collection
    }
    
    /// The `ReadConcern` to apply on operations in here
    var readConcern: ReadConcern? {
        get {
            return collection.readConcern
        }
        set {
            collection.readConcern = newValue
        }
    }
    
    /// The `WriteConcern` to apply on operations in here
    var writeConcern: WriteConcern? {
        get {
            return collection.writeConcern
        }
        set {
            collection.writeConcern = newValue
        }
    }
    
    /// The `Collation` to apply on operations in here
    var collation: Collation? {
        get {
            return collection.collation
        }
        set {
            collection.collation = newValue
        }
    }
    
    /// The filter applied to operations in this slice
    public internal(set) var filter: Query?
    
    /// The sort specification used to get this cursor
    public internal(set) var sort: Sort?
    
    /// The projection specification used to get this cursor
    public internal(set) var projection: Projection?
    
    /// The skip used to get this cursor
    public internal(set) var skip: Int?
    
    /// The limit used to get this cursor
    public internal(set) var limit: Int?
    
    /// The cursor that points to the data
    public private(set) var cursor: Cursor<Element>
    
    /// The next found `Element` in the collection
    ///
    /// WARNING: Will return nil if unable to query the database
    public func next() -> Element? {
        return cursor.next()
    }
    
    /// Iterates over all found `Element`s in the collection
    ///
    /// WARNING: Will return nil if unable to query the database
    public func makeIterator() -> AnyIterator<Element> {
        return AnyIterator {
            self.cursor.next()
        }
    }
    
    /// An efficient and lazy forEach operation specialized for MongoDB.
    ///
    /// Designed to throw errors in the case of a cursor failure, unline normal `for .. in cursor` operations
    public func forEach(_ body: (Element) throws -> Void) throws {
        try cursor.forEach(body)
    }
    
    /// Resets the cursor's position to the beginning
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func reset() throws {
        let slice = try self.find(filter: filter, sort: sort, projection: projection, readConcern: readConcern, collation: collation, skip: skip, limit: limit, connection: nil)
        
        self.cursor = try slice.cursor.flatMap(transform: self.cursor.transform)
    }
    
    /// Counts the amount of `Element`s matching the `filter`. Stops counting when the `limit` it reached
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/count/#dbcmd.count
    ///
    /// - parameter filter: If specified limits the returned amount to anything matching this query
    /// - parameter limit: Limits the amount of scanned `Document`s as specified
    /// - parameter skip: The amount of Documents to skip before counting
    /// - parameter readConcern: The read concern to apply to this operation
    /// - parameter collation: The collation to apply to string comparisons
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    ///
    /// - returns: The amount of matching `Element`s (without consideration of initialization success)
    public func count(limitedTo limit: Int? = nil, skipping skip: Int? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, timingOut afterTimeout: DispatchTimeInterval? = nil) throws -> Int {
        return try self.count(filter: filter, limit: limit, skip: skip, readConcern: readConcern, collation: collation, connection: nil, timeout: afterTimeout)
    }
    
    /// Finds `Element`s in this collection
    ///
    /// Can be used to execute DBCommands in MongoDB 2.6 and below
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/find/#dbcmd.find
    ///
    /// - parameter sort: The Sort Specification used to sort the found Documents
    /// - parameter projection: The Projection Specification used to filter which fields to return
    /// - parameter skip: The amount of Documents to skip before returning the matching Documents
    /// - parameter readConcern: The read concern to apply to this find operation
    /// - parameter collation: The collation to use when comparing strings
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    ///
    /// - returns: The found `Element`
    public func findOne(sorting sort: Sort? = nil, projecting projection: Projection? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, skipping skip: Int? = nil) throws -> Element? {
        return try self.find(sorting: sort, projecting: projection, readConcern: readConcern, collation: collation, skipping: skip, limitedTo: 1, withBatchSize: 1).next()
    }
    
    /// The first found `Element` in the collection
    ///
    /// WARNING: Will return nil if unable to query the database
    public var first: Element? {
        do {
            return try findOne()
        } catch {
            return nil
        }
    }
    
    /// Finds `Element`s in this `Collection`
    ///
    /// Can be used to execute DBCommands in MongoDB 2.6 and below. Be careful!
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/find/#dbcmd.find
    ///
    /// - parameter sort: The Sort Specification used to sort the found Documents
    /// - parameter projection: The Projection Specification used to filter which fields to return
    /// - parameter skip: The amount of Documents to skip before returning the matching Documents
    /// - parameter readConcern: The read concern to apply to this find operation
    /// - parameter collation: The collation to use when comparing strings
    /// - parameter limit: The maximum amount of matching documents to return
    /// - parameter batchSize: The initial amount of Documents to return.
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    ///
    /// - returns: A cursor pointing to the found `Element`s
    public func find(sorting sort: Sort? = nil, projecting projection: Projection? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, skipping skip: Int? = nil, limitedTo limit: Int? = nil, withBatchSize batchSize: Int = 100) throws -> CollectionSlice<Element> {
        return try self.find(filter: filter, sort: sort, projection: projection, readConcern: readConcern, collation: collation, skip: skip, limit: limit, connection: nil).flatMap(transform: self.cursor.transform)
    }
    
    /// Updates all selected `Element`s using a counterpart update `Document`.
    ///
    /// In most cases the `$set` operator is useful for updating only parts of a `Document`
    /// As described here: https://docs.mongodb.com/manual/reference/operator/update/set/#up._S_set
    ///
    /// For more information about this command: https://docs.mongodb.com/manual/reference/command/update/#dbcmd.update
    ///
    /// - parameter document: The Document specification to update these `Element`s with
    /// - parameter writeConcern: The `WriteConcern` used for this operation
    /// - parameter ordered: If true, stop updating when one operation fails - defaults to true
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    @discardableResult
    public func update(to document: Document, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        return try self.update(updates: [(filter ?? [:], document, false, true)], writeConcern: writeConcern, ordered: ordered, connection: nil, timeout: nil)
    }
    
    /// Removes all `Document`s matching the `filter` until the `limit` is reached
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/delete/#dbcmd.delete
    ///
    /// - parameter limit: Limits the amount of removed `Element`s
    /// - parameter writeConcern: The `WriteConcern` used for this operation
    /// - parameter stoppingOnError: If true, stop removing when one operation fails - defaults to true
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    @discardableResult
    public func remove(limitedTo limit: Int = 0, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        return try collection.remove(filter ?? [:], limitedTo: limit, writeConcern: writeConcern, stoppingOnError: ordered)
    }
    
    /// Flatmaps the containing type of this CollectionSlice lazily to another type
    public func flatMap<B>(transform: @escaping (Element) throws -> (B?)) throws -> CollectionSlice<B> {
        let cursor = try Cursor<B>(base: self.cursor, transform: transform)

        return CollectionSlice<B>(cursor: cursor, filter: filter, sort: sort, projection: projection, skip: skip, limit: limit)
    }
    
    /// Creates a new CollectionSlice from a curor and it's metadata
    internal init(cursor: Cursor<Element>, filter: Query?, sort: Sort?, projection: Projection?, skip: Int?, limit: Int?) {
        self.cursor = cursor
        self.filter = filter
        self.sort = sort
        self.projection = projection
        self.skip = skip
        self.limit = limit
    }
}
