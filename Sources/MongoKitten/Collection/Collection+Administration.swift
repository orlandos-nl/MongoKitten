//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

extension Collection {
    /// The touch command loads data from the data storage layer into memory.
    ///
    /// touch can load the data (i.e. documents) indexes or both documents and indexes.
    ///
    /// Using touch to control or tweak what a mongod stores in memory may displace other records data in memory and hinder performance. Use with caution in production systems.
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/touch/#dbcmd.touch
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions, the storage engine doesn't support `touch` or an error occurred
    public func touch(data touchData: Bool, index touchIndexes: Bool) throws {
        let command: Document = [
            "touch": self.name,
            "data": touchData,
            "index": touchIndexes
        ]
        
        let document = try firstDocument(in: try database.execute(command: command))
        
        guard document["ok"] as Int? == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Makes the collection capped
    ///
    /// **Warning: Data loss can and probably will occur**
    ///
    /// It will only contain the first data inserted until the cap is reached
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/convertToCapped/#dbcmd.convertToCapped
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func convertToCapped(cappingAt cap: Int32) throws {
        let command: Document = [
            "convertToCapped": self.name,
            "size": Int32(cap)
        ]
        
        let document = try firstDocument(in: try database.execute(command: command))
        
        guard document["ok"] as Int? == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Tells the MongoDB server to re-index this collection
    ///
    /// **Warning: Very heavy**
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/reIndex/#dbcmd.reIndex
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func reIndex() throws {
        let command: Document = [
            "reIndex": self.name
        ]
        
        let document = try firstDocument(in: try database.execute(command: command))
        
        guard document["ok"] as Int? == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Tells the MongoDB server to make this collection more compact
    ///
    /// **Warning: Very heavy**
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/compact/#dbcmd.compact
    ///
    /// - parameter force: Force the server to do this
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func compact(forced force: Bool? = nil) throws {
        var command: Document = [
            "compact": self.name
        ]
        
        if let force = force {
            command["force"] = force
        }
        
        let document = try firstDocument(in: try database.execute(command: command))
        
        guard document["ok"] as Int? == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Clones this collection to another place and caps it
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/cloneCollectionAsCapped/#dbcmd.cloneCollectionAsCapped
    ///
    /// - parameter otherCollection: The new `Collection` name
    /// - parameter capped: The cap to apply
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func clone(toCappedCollectionNamed otherCollection: String, capped: Int32) throws {
        try database.clone(collection: self, toCappedCollectionNamed: otherCollection, cappedTo: capped)
    }
}
