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

/// DBRef is a structure made to keep references to other MongoDB objects and resolve them easily
public struct DBRef: ValueConvertible {
    /// The collection this referenced Document resides in
    var collection: Collection
    
    /// The referenced Document's _id
    var id: ValueConvertible
    
    /// Converts this DBRef to a BSONPrimitive for easy embedding
    public func makeBSONPrimitive() -> BSONPrimitive {
        return self.documentValue
    }
    
    /// Created a DBRef
    ///
    /// - parameter reference: The _id of the referenced object
    /// - parameter collection: The collection where this references object resides
    public init(referencing reference: ValueConvertible, inCollection collection: Collection) {
        self.id = reference
        self.collection = collection
    }
    
    /// Initializes this DBRef with a Document.
    ///
    /// This initializer fails when the Document isn't a valid DBRef Document
    public init?(_ document: Document, inServer server: Server) {
        guard let database = document["$db"] as String?, let collection = document["$ref"] as String? else {
            server.logger.debug("Provided DBRef document is not valid")
            server.logger.debug(document)
            return nil
        }
        
        guard let id = document[raw: "$id"] else {
            return nil
        }
        
        self.collection = server[database][collection]
        self.id = id
    }
    
    /// Initializes this DBRef with a Document.
    ///
    /// This initializer fails when the Document isn't a valid DBRef Document
    public init?(_ document: Document, inDatabase database: Database) {
        guard let collection = document["$ref"] as String? else {
            return nil
        }
        
        guard let id = document[raw: "$id"] else {
            return nil
        }
        
        self.collection = database[collection]
        self.id = id
    }
    
    /// The Document representation of this DBRef
    public var documentValue: Document {
        return [
            "$ref": self.collection.name,
            "$id": self.id,
            "$db": self.collection.database.name
        ]
    }
    
    /// Resolves this reference to a Document
    ///
    /// - returns: The Document or `nil` if the reference is invalid or the Document has been removed.
    public func resolve() throws -> Document? {
        return try collection.findOne(matching: "_id" == self.id)
    }
}
