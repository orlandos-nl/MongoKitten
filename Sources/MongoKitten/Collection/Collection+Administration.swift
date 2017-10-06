//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Async

extension Collection {
    @discardableResult
    public func touch(data: Bool, index: Bool) throws -> Future<Void> {
        let command = Commands.Touch(collection: self, data: data, index: index)
        
        return try command.execute(on: database)
    }
    
    @discardableResult
    public func convertToCapped(cappingAt cap: Int) throws -> Future<Void> {
        let command = Commands.ConvertToCapped(collection: self, toCap: cap)
        
        return try command.execute(on: database)
    }
    
    @discardableResult
    public func rebuildIndexes() throws -> Future<Void> {
        let command = Commands.RebuildIndexes(collection: self)
        
        return try command.execute(on: database)
    }
    
    @discardableResult
    public func compact(forced force: Bool? = nil) throws -> Future<Void> {
        var command = Commands.Compact(collection: self)
        
        command.force = force
        
        return try command.execute(on: database)
    }
    
    @discardableResult
    public func clone(renameTo otherCollection: String, cappingAt cap: Int) throws -> Future<Void> {
        let command = Commands.CloneCollectionAsCapped(collection: self, newName: otherCollection, cap: cap)
        
        return try command.execute(on: database)
    }
    
    @discardableResult
    public func drop() throws -> Future<Void> {
        let command = Commands.Drop(collection: self)
        
        return try command.execute(on: database)
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
    
    struct Drop: Command {
        var drop: String
        
        static var writing = true
        static var emitsCursor = false
        
        init(collection: Collection) {
            self.drop = collection.name
        }
    }
}
