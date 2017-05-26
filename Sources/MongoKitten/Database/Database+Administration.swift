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
    /// - parameter validator: The Document validator to apply to all Documents in this collection. All Documents must match this query 
    /// - parameter options: Optionally, configuration options for creating this collection.
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    ///
    /// - returns: The created collection
    @discardableResult
    public func createCollection(named name: String, validatedBy validator: Query? = nil, options: Document? = nil) throws -> Collection {
        var command: Document = ["create": name]

        if let options = options {
            for option in options {
                command[option.key] = option.value
            }
        }
        
        log.verbose("Creating a collection named \"\(name)\" in \(self)\(validator != nil ? " with the provided validator" : "")")
        
        if let validator = validator {
            command["validator"] = validator
            log.debug("Validator:" + validator.makeDocument().makeExtendedJSON().serializedString())
        }

        let document = try firstDocument(in: try execute(command: command))

        guard Int(document["ok"]) == 1 else {
            log.error("createCollection for collection \"\(name)\" was not successful because of the following error")
            log.error(document)
            log.debug("createCollection failed with the following options:")
            log.debug(options ?? [:])
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
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    ///
    /// - returns: A cursor to the resulting documents with collection info
    internal func getCollectionInfos(matching filter: Document? = nil) throws -> Cursor<Document> {
        guard server.buildInfo.version >= Version(3, 0, 0) else {
            return try self["system.namespaces"].find().cursor
        }
        
        var request: Document = ["listCollections": 1]
        
        log.verbose("Listing all collections\(filter != nil ? " using the provided filter" : "")")
        
        if let filter = filter {
            log.debug("The collections are matches against the following filter: " + filter.makeExtendedJSON().serializedString())
            request["filter"] = filter
        }

        let connection = try server.reserveConnection(authenticatedFor: self)
        
        let reply = try execute(command: request, using: connection)

        let result = try firstDocument(in: reply)

        guard let cursor = Document(result["cursor"]), Int(result["ok"]) == 1 else {
            log.error("The collection infos could not be fetched because of the following error")
            log.error(result)
            log.debug("The collection infos were being filtered using the following query")
            log.debug(filter ?? [:])
            self.server.returnConnection(connection)
            throw MongoError.commandFailure(error: result)
        }

        do {
            return try Cursor(cursorDocument: cursor, collection: self["$cmd"], connection: connection, chunkSize: 100, transform: { $0 })
        } catch {
            self.server.returnConnection(connection)
            throw error
        }
    }
    
    public func getCollectionInfos(matching filter: Document? = nil) throws -> AnyIterator<Document> {
        return try getCollectionInfos(matching: filter).makeIterator()
    }

    /// Gets the `Collection`s in this `Database`
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    ///
    /// - parameter matching: The filter to apply when looking for Collections
    ///
    /// - returns: A `Cursor` to all `Collection`s in this `Database`
    public func listCollections(matching filter: Document? = nil) throws -> Cursor<Collection> {
        let infoCursor = try self.getCollectionInfos(matching: filter) as Cursor<Document>
        return try Cursor(base: infoCursor) { collectionInfo in
            if self.server.buildInfo.version >= Version(3, 0, 0) {
                guard let name = String(collectionInfo["name"]) else {
                    return nil
                }
                
                return self[name]
            } else {
                guard var name = String(collectionInfo["name"]), name.hasPrefix(self.name + ".") else {
                    return nil
                }
                
                name.characters.removeFirst(self.name.characters.count + 1)
                let split = name.characters.split(separator: ".")
                
                if split.count > 1, let last = split.last {
                    // is index
                    if String(last).hasPrefix("$") {
                        return nil
                    }
                }
                
                return self[name]
            }
        }
    }

    /// Drops this database and it's collections
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/dropDatabase/#dbcmd.dropDatabase
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func drop() throws {
        let command: Document = [
            "dropDatabase": Int32(1)
        ]

        let document = try firstDocument(in: try execute(command: command))

        guard Int(document["ok"]) == 1 else {
            log.error("dropDatabase was not successful for \"\(self.name)\" because of the following error")
            log.error(document)
            throw MongoError.commandFailure(error: document)
        }
    }

    /// Copies this `Database` and `Collection`s to another `Database`
    ///
    /// - parameter database: The new database name
    /// - parameter user: The optional user credentials that you'll use to authenticate in the new DB
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
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
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func clone(toNamespace ns: String, fromServer server: String, filteredBy filter: Query? = nil) throws {
        var command: Document = [
            "cloneCollection": ns,
            "from": server
        ]

        if let filter = filter {
            command["query"] = filter.queryDocument
        }

        let document = try firstDocument(in: try execute(command: command))

        guard Int(document["ok"]) == 1 else {
            log.error("cloneCollection was not successful because of the following error")
            log.error(document)
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
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func clone(toNamespace ns: String, fromServer server: String, filteredBy filter: Document? = nil) throws {
        var command: Document = [
            "cloneCollection": ns,
            "from": server
        ]

        if let filter = filter {
            command["query"] = filter
        }
        
        log.verbose("Cloning \(self) to namespace \(ns)")

        let document = try firstDocument(in: try execute(command: command))

        // If we're done
        if Bool(document["done"]) == true {
            return
        }

        guard Int(document["ok"]) == 1 else {
            log.error("cloneCollection was not successful because of the following error")
            log.error(document)
            throw MongoError.commandFailure(error: document)
        }
    }

    /// Clones a collection in this database to another name in this database and caps it
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/cloneCollectionAsCapped/#dbcmd.cloneCollectionAsCapped
    ///
    /// - parameter instance: The collection to clone
    /// - parameter otherCollection: The new name to clone it to
    /// - parameter capped: The new capacity to apply
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func clone(collection instance: Collection, toCappedCollectionNamed otherCollection: String, cappedTo capped: Int) throws {
        let command: Document = [
            "cloneCollectionAsCapped": instance.name,
            "toCollection": otherCollection,
            "size": Int32(capped)
        ]

        log.verbose("Cloning \(instance) to be named \"\(otherCollection)\" capped to \(capped) bytes")
        
        let document = try firstDocument(in: try execute(command: command))

        guard Int(document["ok"]) == 1 else {
            log.error("cloneCollectionAsCapped was not successful because of the following error")
            log.error(document)
            throw MongoError.commandFailure(error: document)
        }
    }
}
