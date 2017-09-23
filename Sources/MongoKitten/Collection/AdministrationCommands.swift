//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

protocol Command: Encodable {
    static var writing: Bool { get }
    static var emitsCursor: Bool { get }
}

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

extension Commands {
    struct Touch: Command {
        var touch: String
        var data: Bool
        var index: Bool
        
        static var writing = true
        static var emitsCursor = false
        
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
        
        static var writing = true
        static var emitsCursor = false
        
        init(collection: Collection, toCap cap: Int) {
            self.convertTocapped = collection.name
            self.size = cap
        }
    }
    
    struct RebuildIndexes: Command {
        var reIndex: String
        
        static var writing = true
        static var emitsCursor = false
        
        init(collection: Collection) {
            self.reIndex = collection.name
        }
    }
    
    struct Compact: Command {
        var compact: String
        var force: Bool?
        
        static var writing = true
        static var emitsCursor = false
        
        init(collection: Collection) {
            self.compact = collection.name
        }
    }
    
    struct CloneCollectionAsCapped: Command {
        var cloneCollectionAsCapped: String
        var toCollection: String
        var size: Int
        
        static var writing = true
        static var emitsCursor = false
        
        init(collection: Collection, newName: String, cap: Int) {
            self.cloneCollectionAsCapped = collection.name
            self.toCollection = newName
            self.size = cap
        }
    }
}

import BSON
import Schrodinger

extension Database {
    func execute<E: Command, D: Decodable>(_ command: E, expecting type: D.Type) throws -> Future<D> {
        return try execute(command) { reply, _ in
            guard let first = reply.documents.first else {
                throw InternalMongoError.incorrectReply(reply: reply)
            }
            
            return try BSONDecoder().decode(D.self, from: first)
        }
    }
    
    func execute<E: Command, T>(
        _ command: E,
        handle result: @escaping ((ServerReply, Connection) throws -> (T))
    ) throws -> Future<T> {
        let command = try BSONEncoder().encode(command)
        
        let connection = try server.reserveConnection(writing: E.writing, authenticatedFor: self)
        
        defer {
            if !E.emitsCursor {
                server.returnConnection(connection)
            }
        }
        
        return try execute(command: command, using: connection).map { reply in
            return try result(reply, connection)
        }
    }
}
