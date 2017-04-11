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
import ExtendedJSON

extension Document : CustomDebugStringConvertible {
    /// Appends this Document to a collection
    ///
    /// - parameter collection: The collection to append this Document to
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public mutating func append(to collection: Collection) throws {
        let id = try collection.insert(self)
        self["_id"] = id
    }
    
    /// Upserts this Document into a collection.
    ///
    /// - parameter collection: The collection to upsert this Doucment into
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public mutating func upsert(into collection: Collection) throws {
        let id = self["_id"] ?? ObjectId()
        self["_id"] = id
        
        try collection.update("_id" == id, to: self, upserting: true)
    }
    
    public var debugDescription: String {
        return self.makeExtendedJSON().serializedString()
    }
}
