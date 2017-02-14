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

extension Database {


    /// Creates a new collection explicitly.
    ///
    /// Because MongoDB creates a collection implicitly when the collection is first referenced in a
    /// command, this method is used primarily for creating new collections that use specific
    /// options. For example, you use `createCollection()` to create a capped collection, or to
    /// create a new collection that uses document validation. `createCollection()` is also used to
    /// pre-allocate space for an ordinary collection
    ///
    /// For more information and a full list of options: https://docs.mongodb.com/manual/reference/command/create/
    ///
    /// - parameter name: The name of the collection to create.
    /// - parameter options: Optionally, configuration options for creating this collection.
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: The created collection
    @discardableResult
    public func createCollection(named name: String, validatedBy validator: Query? = nil, options: Document? = nil) throws -> Collection {
        var command: Document = ["create": name]

        if let options = options {
            for option in options {
                command[raw: option.key] = option.value
            }
        }
        
        command[raw: "validator"] = validator

        let document = try firstDocument(in: try execute(command: command))

        guard document["ok"] as Int? == 1 else {
            logger.error("createCollection for collection \"\(name)\" was not successful because of the following error")
            logger.error(document)
            logger.error("createCollection failed with the following options:")
            logger.error(options ?? [:])
            throw MongoError.commandFailure(error: document)
        }
        
        return self[name]
    }

    /// All information about the `Collection`s in this `Database`
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/listCollections/#dbcmd.listCollections
    ///
    /// - parameter matching: The filter to apply when searching for this information
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: A cursor to the resulting documents with collection info
    public func getCollectionInfos(matching filter: Document? = nil) throws -> Cursor<Document> {
        var request: Document = ["listCollections": 1]
        if let filter = filter {
            request["filter"] = filter
        }

        let reply = try execute(command: request)

        let result = try firstDocument(in: reply)

        guard let cursor = result["cursor"] as Document?, result["ok"] as Int? == 1 else {
            logger.error("The collection infos could not be fetched because of the following error")
            logger.error(result)
            logger.error("The collection infos were being found using the following filter")
            logger.error(filter ?? [:])
            throw MongoError.commandFailure(error: result)
        }

        return try Cursor(cursorDocument: cursor, collection: self["$cmd"], chunkSize: 10, transform: { $0 })
    }

    /// Gets the `Collection`s in this `Database`
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - parameter matching: The filter to apply when looking for Collections
    ///
    /// - returns: A `Cursor` to all `Collection`s in this `Database`
    public func listCollections(matching filter: Document? = nil) throws -> Cursor<Collection> {
        let infoCursor = try self.getCollectionInfos(matching: filter)
        return Cursor(base: infoCursor) { collectionInfo in
            return self[collectionInfo["name"] as String? ?? ""]
        }
    }

    /// Drops this database and it's collections
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/dropDatabase/#dbcmd.dropDatabase
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func drop() throws {
        let command: Document = [
            "dropDatabase": Int32(1)
        ]

        let document = try firstDocument(in: try execute(command: command))

        guard document["ok"] as Int? == 1 else {
            logger.error("dropDatabase was not successful for \"\(self.name)\" because of the following error")
            logger.error(document)
            throw MongoError.commandFailure(error: document)
        }
    }

    /// Copies this `Database` and `Collection`s to another `Database`
    ///
    /// - parameter database: The new database name
    /// - parameter user: The optional user credentials that you'll use to authenticate in the new DB
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func copy(toDatabase database: String, asUser user: (user: String, nonce: String, password: String)? = nil) throws {
        try server.copy(database: self.name, to: database, as: user)
    }

    /// Clones collection in the namespace from a server to this database
    /// Optionally filters data you don't want
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/cloneCollection/#dbcmd.cloneCollection
    ///
    /// - parameter namespace: The remote namespace
    /// - parameter server: The server URI you're copying from
    /// - parameter filter: The query you're using to filter this
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func clone(toNamespace ns: String, fromServer server: String, filteredBy filter: Query? = nil) throws {
        var command: Document = [
            "cloneCollection": ns,
            "from": server
        ]

        if let filter = filter {
            command["query"] = filter.queryDocument
        }

        let document = try firstDocument(in: try execute(command: command))

        guard document["ok"] as Int? == 1 else {
            logger.error("cloneCollection was not successful because of the following error")
            logger.error(document)
            throw MongoError.commandFailure(error: document)
        }
    }

    /// Clones collection in the namespace from a server to this database
    /// Optionally filters data you don't want
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/cloneCollection/#dbcmd.cloneCollection
    ///
    /// - parameter namespace: The remote namespace
    /// - parameter from: The server URI you're copying from
    /// - parameter filtering: The document filter you're using to filter this
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func clone(toNamespace ns: String, fromServer server: String, filteredBy filter: Document? = nil) throws {
        var command: Document = [
            "cloneCollection": ns,
            "from": server
        ]

        if let filter = filter {
            command["query"] = filter
        }

        let document = try firstDocument(in: try execute(command: command))

        // If we're done
        if document["done"] as Bool? == true {
            return
        }

        guard document["ok"] as Int? == 1 else {
            logger.error("cloneCollection was not successful because of the following error")
            logger.error(document)
            throw MongoError.commandFailure(error: document)
        }
    }

    /// Clones a collection in this database to another name in this database and caps it
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/cloneCollectionAsCapped/#dbcmd.cloneCollectionAsCapped
    ///
    /// - parameter collection: The collection to clone
    /// - parameter otherCollection: The new name to clone it to
    /// - parameter capped: The new cap
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func clone(collection instance: Collection, toCappedCollectionNamed otherCollection: String, cappedTo capped: Int32) throws {
        let command: Document = [
            "cloneCollectionAsCapped": instance.name,
            "toCollection": otherCollection,
            "size": Int32(capped)
        ]

        let document = try firstDocument(in: try execute(command: command))

        guard document["ok"] as Int? == 1 else {
            logger.error("cloneCollectionAsCapped was not successful because of the following error")
            logger.error(document)
            throw MongoError.commandFailure(error: document)
        }
    }
}
