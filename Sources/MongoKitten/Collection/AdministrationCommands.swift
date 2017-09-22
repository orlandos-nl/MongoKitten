//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

public protocol Command: Encodable {}

extension Command {
    func execute(on database: Database) throws -> Future<Void> {
        let response = try database.execute(self, expecting: Document.self)
        
        return response.map { document in
            guard Int(document["ok"]) == 1 else {
                throw MongoError.commandFailure(error: document)
            }
        }
    }
}

enum Commands {
    struct Touch: Command {
        var touch: String
        var data: Bool
        var index: Bool
        
        init(collection: Collection, data: Bool, index: Bool) {
            self.touch = collection.name
            self.data = data
            self.index = index
        }
    }
    
    struct ConvertToCapped: Command {
        var convertTocapped: String
        
        // TODO: Int32?
        var size: Int
        
        init(collection: Collection, toCap cap: Int) {
            self.convertTocapped = collection.name
            self.size = cap
        }
    }
    
    struct RebuildIndexes: Command {
        var reIndex: String
        
        init(collection: Collection) {
            self.reIndex = collection.name
        }
    }
    
    struct Compact: Command {
        var compact: String
        var force: Bool?
        
        init(collection: Collection) {
            self.compact = collection.name
        }
    }
    
    struct CloneCollectionAsCapped: Command {
        var cloneCollectionAsCapped: String
        var toCollection: String
        var size: Int
        
        init(collection: Collection, newName: String, cap: Int) {
            self.cloneCollectionAsCapped = collection.name
            self.toCollection = newName
            self.size = cap
        }
    }
}

enum Responses {
    struct Okay: Decodable {
        var ok: Bool
    }
}

import BSON
import Schrodinger

extension Database {
    func execute<E: Encodable, D: Decodable>(_ command: E, expecting type: D.Type) throws -> Future<D> {
        let command = try BSONEncoder().encode(command)
        
        return try execute(command: command).map { reply in
            guard let first = reply.documents.first else {
                throw InternalMongoError.incorrectReply(reply: reply)
            }
            
            return try BSONDecoder().decode(D.self, from: first)
        }
    }
}
