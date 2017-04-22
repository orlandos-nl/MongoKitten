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
    /// touch can load the data (i.e. documents), indexes or both documents and indexes.
    ///
    /// Using touch to control or tweak what a mongod stores in memory may displace other records data in memory and hinder performance. Use with caution in production systems.
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/touch/#dbcmd.touch
    ///
    /// - parameter touchData: When true, tells mongoDB to load all this collection's data (Documents) in memory
    /// - parameter touchIndexes: When true, tells mongoDB to load all this collection's indexes
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions, the storage engine doesn't support `touch` or an error occurred
    public func touch(data touchData: Bool, index touchIndexes: Bool) throws {
        let command: Document = [
            "touch": self.name,
            "data": touchData,
            "index": touchIndexes
        ]
        
        log.verbose("Pre-caching \(touchData ? "data" : "")\(touchData && touchIndexes ? "and" : "")\(touchIndexes ? "indexes" : "") on \(self)")
        
        let document = try firstDocument(in: try database.execute(command: command))
        
        guard Int(document["ok"]) == 1 else {
            log.error(document)
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Makes the collection capped, meaning it can only contain `<cap>` amount of Documents
    ///
    /// **Warning: Data loss can and probably will occur**
    ///
    /// It will only contain the first data inserted until the cap is reached
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/convertToCapped/#dbcmd.convertToCapped
    ///
    /// - parameter cap: The capacity to enforce on this collection
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func convertToCapped(cappingAt cap: Int) throws {
        let command: Document = [
            "convertToCapped": self.name,
            "size": Int32(cap)
        ]
        
        log.verbose("Converting \(self) to a collection capped to \(cap) bytes")
        
        let document = try firstDocument(in: try database.execute(command: command))
        
        guard Int(document["ok"]) == 1 else {
            log.error(document)
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Tells the MongoDB server to re-index this collection
    ///
    /// **Warning: Very heavy**
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/reIndex/#dbcmd.reIndex
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func rebuildIndexes() throws {
        let command: Document = [
            "reIndex": self.name
        ]
        
        log.verbose("Rebuilding indexes for \(self)")
        
        let document = try firstDocument(in: try database.execute(command: command))
        
        guard Int(document["ok"]) == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Tells the MongoDB server to make this collection more compact, optimizing disk storage space
    ///
    /// **Warning: Very heavy**
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/compact/#dbcmd.compact
    ///
    /// - parameter force: Force the server to do this on a replica set primary
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func compact(forced force: Bool? = nil) throws {
        var command: Document = [
            "compact": self.name
        ]
        
        if let force = force {
            command["force"] = force
        }
        
        log.verbose("Optimizing disk storage space \(force == true ? "forcefully " : "") for \(self)")
        
        let document = try firstDocument(in: try database.execute(command: command))
        
        guard Int(document["ok"]) == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Clones this collection to another place and caps it
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/cloneCollectionAsCapped/#dbcmd.cloneCollectionAsCapped
    ///
    /// - parameter otherCollection: The new collection name
    /// - parameter capped: The capacity to enforce
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func cloneToCappedCollection(named otherCollection: String, capped: Int) throws {
        try database.clone(collection: self, toCappedCollectionNamed: otherCollection, cappedTo: capped)
    }
}
