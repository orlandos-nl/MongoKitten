//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Schrodinger

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
}
