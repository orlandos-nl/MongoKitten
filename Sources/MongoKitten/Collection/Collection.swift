//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//
import Foundation
import BSON
import Dispatch
import Async

public typealias MongoCollection = Collection

/// Represents a single MongoDB collection.
///
/// **### Definition ###**
///
/// A grouping of MongoDB documents. A collection is the equivalent of an RDBMS table. A collection exists within a single database. Collections do not enforce a schema. Documents within a collection can have different fields. Typically, all documents in a collection have a similar or related purpose. See Namespaces.
public final class Collection: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.name)
    }
    
    /// The Database this collection is in
    public private(set) var database: Database
    
    /// The collection name
    public private(set) var name: String
    
    public var connectionPool: ConnectionPool {
        return database.connectionPool
    }
    
    /// The full (computed) collection name. Created by adding the Database's name with the Collection's name with a dot to seperate them
    public var namespace: String {
        return "\(database.name).\(name)"
    }
    
    public var `default` = Preferences()
    
    /// Initializes this collection with a database and name
    ///
    /// - parameter name: The collection name
    /// - parameter database: The database this `Collection` exists in
    internal init(named name: String, in database: Database) {
        self.database = database
        self.name = name
    }
}

//    /// Finds and removes the all `Document`s in this `Collection` that match the provided `Query`.
//    ///
//    /// TODO: Better docs
//    ///
//    /// For more information: https://docs.mongodb.com/manual/reference/command/findAndModify/#dbcmd.findAndModify
//    ///
//    /// - parameter query: The `Query` to match the `Document`s in the `Collection` against for removal
//    /// - parameter sort: The sort order specification to use while searching for the first Document.
//    /// - parameter projection: Which fields to project and how according to projection specification
//    ///
//    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
//    ///
//    /// - returns: The `Value` received from the server as specified in the link of the additional information
//    public func findAndRemove(_ query: Query? = nil, sortedBy sort: Sort? = nil, projection: Projection? = nil) throws -> Document {
//        var command: Document = ["findAndModify": self.name]
//
//        if let query = query {
//            command["query"] = query.queryDocument
//        }
//
//        if let sort = sort {
//            command["sort"] = sort
//        }
//
//        command["remove"] = true
//
//        if let projection = projection {
//            command["fields"] = projection
//        }
//
//        let document = try firstDocument(in: try database.execute(command: command).blockingAwait(timeout: .seconds(3)))
//
//        guard Int(document["ok"]) == 1 && (Document(document["writeErrors"]) ?? [:]).count == 0, let value = Document(document["value"]) else {
//            throw MongoError.commandFailure(error: document)
//        }
//
//        return value
//    }
//
//    /// Specifies to `findAndUpdate` what kind of Document to return.
//    ///
//    /// TODO: Better docs
//    public enum ReturnedDocument {
//        /// The new Document, after updating it
//        case new
//
//        /// The old Document, before updating it
//        case old
//
//        /// Converts this enum case to a boolean for `findAndUpdate`
//        internal var boolean: Bool {
//            switch self {
//            case .new:
//                return true
//            case .old:
//                return false
//            }
//        }
//    }
//
//    /// Finds and updates all `Document`s in this `Collection` that match the provided `Query`.
//    ///
//    /// TODO: Better docs
//    ///
//    /// For more information: https://docs.mongodb.com/manual/reference/command/findAndModify/#dbcmd.findAndModify
//    ///
//    /// - parameter query: The `Query` to match the `Document`s in the `Collection` against for removal
//    /// - parameter with: The new Document
//    /// - parameter upserting: Insert if no Document matches the query
//    /// - parameter returnedDocument: The specification that determens the returned value of this function
//    /// - parameter sort: The sort order specification to use while searching for the first Document.
//    /// - parameter projection: Which fields to project and how according to projection specification
//    ///
//    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
//    ///
//    /// - returns: The `Value` received from the server as specified in the link of the additional information
//    public func findAndUpdate(_ query: Query? = nil, with: Document, upserting: Bool? = nil, returnedDocument: ReturnedDocument = .old, sortedBy sort: Sort? = nil, projection: Projection? = nil) throws -> Document {
//        var command: Document = ["findAndModify": self.name]
//
//        if let query = query {
//            command["query"] = query.queryDocument
//        }
//
//        if let sort = sort {
//            command["sort"] = sort
//        }
//
//        command["update"] = with
//        command["new"] = returnedDocument.boolean
//        command["upsert"] = upserting
//
//        if let projection = projection {
//            command["fields"] = projection
//        }
//
//        let document = try firstDocument(in: try database.execute(command: command).blockingAwait(timeout: .seconds(3)))
//
//        guard Int(document["ok"]) == 1 && (Document(document["writeErrors"]) ?? [:]).count == 0, let value = Document(document["value"]) else {
//            throw MongoError.commandFailure(error: document)
//        }
//
//        return value
//    }
//
//    /// Returns all distinct values for a key in this collection. Allows filtering using query
//    ///
//    /// For more information: https://docs.mongodb.com/manual/reference/command/distinct/#dbcmd.distinct
//    ///
//    /// - parameter field: The key that we look for distincts for
//    /// - parameter query: The query applied on all Documents before passing allowing their field at this key to be a distinct
//    /// - parameter readConcern: The read concern to apply on this read operation.
//    /// - parameter collation: The collation used to compare strings
//    ///
//    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
//    ///
//    /// - returns: A list of all distinct values for this key
//    public func distinct(on field: String, filtering query: Query? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil) throws -> [BSON.Primitive]? {
//        var command: Document = ["distinct": self.name, "key": field]
//
//        if let query = query {
//            command["query"] = query
//        }
//
//        command["readConcern"] = readConcern ?? self.readConcern
//        command["collation"] = collation ?? self.collation
//
//        return [Primitive](try firstDocument(in: try self.database.execute(command: command, writing: false).blockingAwait(timeout: .seconds(3)))["values"])
//    }
//
//    /// Changes the name of an existing collection. To move the collection to a different database, use `move` instead.
//    ///
//    /// For more information: https://docs.mongodb.com/manual/reference/command/renameCollection/#dbcmd.renameCollection
//    ///
//    /// - parameter to: The new name for this collection
//    ///
//    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
//    public func rename(to newName: String) throws {
//        try self.move(to: database, named: newName)
//    }
//
//    /// Move this collection to another database. Can also rename the collection in one go.
//    ///
//    /// **Users must have access to the admin database to run this command.**
//    ///
//    /// For more information: https://docs.mongodb.com/manual/reference/command/renameCollection/#dbcmd.renameCollection
//    ///
//    /// - parameter to: The database to move this collection to
//    /// - parameter named: The new name for this collection
//    ///
//    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
//    public func move(to database: Database, named collectionName: String? = nil, overwritingExistingCollection dropOldTarget: Bool? = nil) throws {
//        // TODO: Fail if the target database exists.
//        var command: Document = [
//            "renameCollection": self.fullName,
//            "to": "\(database.name).\(collectionName ?? self.name)"
//        ]
//
//        if let dropOldTarget = dropOldTarget { command["dropTarget"] = dropOldTarget }
//
//        _ = try self.database.server["admin"].execute(command: command)
//
//        self.database = database
//        self.name = collectionName ?? name
//    }
//
//    /// Creates an `Index` in this `Collection` on the specified keys.
//    ///
//    /// Usage:
//    ///
//    /// ```swift
//    /// // Makes "username" unique and indexed. Sort order doesn't technically matter much
//    /// try collection.createIndex(named: "login", .sort(field: "username", order: .ascending), .unique)
//    /// ```
//    ///
//    /// For more information: https://docs.mongodb.com/manual/reference/command/createIndexes/#dbcmd.createIndexes
//    ///
//    /// - parameter name: The name of this index used to identify it
//    /// - parameter parameters: All `IndexParameter` options applied to the index
//    ///
//    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
//    public func createIndex(named name: String, withParameters parameters: IndexParameter...) throws {
//        try self.createIndexes([(name: name, parameters: parameters)])
//    }
//
//    /// Creates multiple indexes as specified
//    ///
//    /// For more information: https://docs.mongodb.com/manual/reference/command/createIndexes/#dbcmd.createIndexes
//    ///
//    /// - parameter indexes: The indexes to create. Accepts an array of tuples (each tuple representing an Index) which an contain a name and always contains an array of `IndexParameter`.
//    ///
//    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
//    public func createIndexes(_ indexes: [(name: String, parameters: [IndexParameter])]) throws {
//        guard let wireVersion = database.server.serverData?.maxWireVersion , wireVersion >= 2 else {
//            throw MongoError.unsupportedOperations
//        }
//
//        var indexDocs = [Document]()
//
//        for index in indexes {
//            var indexDocument: Document = [
//                "name": index.name
//            ]
//
//            for parameter in index.parameters {
//                indexDocument += parameter.document
//            }
//
//            indexDocs.append(indexDocument)
//        }
//
//
//        let document = try firstDocument(in: try database.execute(command: ["createIndexes": self.name, "indexes": Document(array: indexDocs)]).blockingAwait(timeout: .seconds(3)))
//
//        guard Int(document["ok"]) == 1 else {
//            throw MongoError.commandFailure(error: document)
//        }
//    }
//
//    /// Remove the index specified
//    /// Warning: Write-locks the database whilst this process is executed
//    ///
//    /// For more information: https://docs.mongodb.com/manual/reference/command/dropIndexes/#dbcmd.dropIndexes
//    ///
//    /// - parameter index: The index name (as specified when creating the index) that will removed. `*` for all indexes
//    ///
//    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
//    public func dropIndex(named index: String) throws {
//        let reply = try database.execute(command: ["dropIndexes": self.name, "index": index]).blockingAwait(timeout: .seconds(3))
//
//        let dropIndexResponse = try firstDocument(in: reply)
//        guard Int(dropIndexResponse["ok"]) == 1 else {
//            throw MongoError.commandFailure(error: dropIndexResponse)
//        }
//    }
//
//    /// Lists all indexes for this collection as Documents
//    ///
//    /// ```swift
//    /// for indexDoucment in try collection.listIndexes() {
//    ///   print(indexDocument)
//    ///   ...
//    /// }
//    /// ```
//    ///
//    /// For more information: https://docs.mongodb.com/manual/reference/command/listIndexes/#dbcmd.listIndexes
//    ///
//    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
//    ///
//    /// - returns: A Cursor pointing to the Index results
//    public func listIndexes() throws -> Cursor<Document> {
//        guard database.server.buildInfo.version >= Version(3,0,0) else {
//            throw MongoError.unsupportedOperations
//        }
//
//        let result = try firstDocument(in: try database.execute(command: ["listIndexes": self.name], writing: false).blockingAwait(timeout: .seconds(3)))
//
//        guard let cursorDocument = Document(result["cursor"]) else {
//            throw MongoError.cursorInitializationError(cursorDocument: result)
//        }
//
//        let connection = try database.server.reserveConnection(authenticatedFor: self.database)
//
//        return try Cursor(cursorDocument: cursorDocument, collection: self.name, database: self.database, connection: connection, chunkSize: 100, transform: { $0 })
//    }
//
//    /// Modifies the collection. Requires access to `collMod`
//    ///
//    /// You can use this method, for example, to change the validator on a collection:
//    ///
//    /// ```swift
//    /// try collection.modify(flags: ["validator": ["name": ["$type": "string"]]])
//    /// ```
//    ///
//    /// For more information: https://docs.mongodb.com/manual/reference/command/collMod/#dbcmd.collMod
//    ///
//    /// - parameter flags: The modification you want to perform. See the MongoDB documentation for more information.
//    ///
//    /// - throws: When MongoDB doesn't return a document indicating success, we'll throw a `MongoError.commandFailure()` containing the error document sent by the server
//    /// - throws: When the `flags` document contains the key `collMod`, which is prohibited.
//    public func set(flags: Document) throws {
//        let command = flags + ["collMod": self.name]
//
//        log.verbose("Modifying \(self) with \(flags.count) flags")
//        log.debug(flags)
//
//        let result = try firstDocument(in: database.execute(command: command + flags).blockingAwait(timeout: .seconds(3)))
//
//        guard Int(result["ok"]) == 1 else {
//            log.error("Collection modification for \(self) failed")
//            log.error(result)
//            throw MongoError.commandFailure(error: result)
//        }
//    }
//}
