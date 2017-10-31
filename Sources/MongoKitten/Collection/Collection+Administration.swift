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

extension DatabaseConnection {
    @discardableResult
    public func touch(collection: MongoCollection, data: Bool, index: Bool) -> Future<Void> {
        let command = Commands.Touch(collection: collection, data: data, index: index)
        
        return command.execute(on: self)
    }
    
    @discardableResult
    public func convert(collection: MongoCollection, toCap cap: Int) -> Future<Void> {
        let command = Commands.ConvertToCapped(collection: collection, toCap: cap)
        
        return command.execute(on: self)
    }
    
    @discardableResult
    public func rebuildIndexes(on collection: MongoCollection) -> Future<Void> {
        let command = Commands.RebuildIndexes(collection: collection)
        
        return command.execute(on: self)
    }
    
    @discardableResult
    public func compact(_ collection: MongoCollection, forced force: Bool? = nil) -> Future<Void> {
        var command = Commands.Compact(collection: collection)
        
        command.force = force
        
        return command.execute(on: self)
    }
    
    @discardableResult
    public func clone(_ collection: MongoCollection, renameTo otherCollection: String, cappingAt cap: Int) -> Future<Void> {
        let command = Commands.CloneCollectionAsCapped(collection: collection, newName: otherCollection, cap: cap)
        
        return command.execute(on: self)
    }
    
    @discardableResult
    public func drop(_ collection: MongoCollection) -> Future<Void> {
        let command = Commands.Drop(collection: collection)
        
        return command.execute(on: self)
    }
}

extension Commands {
    struct Touch: Command {
        var touch: String
        var data: Bool
        var index: Bool
        
        let targetCollection: MongoCollection
        
        static var writing = true
        static var emitsCursor = false
        
        init(collection: Collection, data: Bool, index: Bool) {
            self.touch = collection.name
            self.data = data
            self.index = index
            self.targetCollection = collection
        }
    }
    
    struct ConvertToCapped: Command {
        var convertTocapped: String
        
        // TODO: Int32?
        var size: Int
        
        let targetCollection: MongoCollection
        
        static var writing = true
        static var emitsCursor = false
        
        init(collection: Collection, toCap cap: Int) {
            self.convertTocapped = collection.name
            self.size = cap
            self.targetCollection = collection
        }
    }
    
    struct RebuildIndexes: Command {
        var reIndex: String
        
        let targetCollection: MongoCollection
        
        static var writing = true
        static var emitsCursor = false
        
        init(collection: Collection) {
            self.reIndex = collection.name
            self.targetCollection = collection
        }
    }
    
    struct Compact: Command {
        var compact: String
        var force: Bool?
        
        let targetCollection: MongoCollection
        
        static var writing = true
        static var emitsCursor = false
        
        init(collection: Collection) {
            self.compact = collection.name
            self.targetCollection = collection
        }
    }
    
    struct CloneCollectionAsCapped: Command {
        var cloneCollectionAsCapped: String
        var toCollection: String
        var size: Int
        
        let targetCollection: MongoCollection
        
        static var writing = true
        static var emitsCursor = false
        
        init(collection: Collection, newName: String, cap: Int) {
            self.targetCollection = collection
            self.cloneCollectionAsCapped = collection.name
            self.toCollection = newName
            self.size = cap
        }
    }
    
    struct Drop: Command {
        var drop: String
        
        let targetCollection: MongoCollection
        
        static var writing = true
        static var emitsCursor = false
        
        init(collection: Collection) {
            self.drop = collection.name
            self.targetCollection = collection
        }
    }
}
