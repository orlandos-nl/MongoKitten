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

extension Document {
    mutating func append(to collection: Collection) throws {
        let id = try collection.insert(self)
        self["_id"] = id
    }
    
    mutating func upsert(into collection: Collection) throws {
        let id = self["_id"] ?? ObjectId()
        self["_id"] = id
        
        try collection.update("_id" == id, to: self, upserting: true)
    }
}
