//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Foundation
import LogKitten
import BSON

/// A Cursor is a pointer to a sequence/collection of Documents on the MongoDB server.
///
/// It can be looped over using a `for let document in cursor` loop like any other sequence.
///
/// It can be transformed into an array with `Array(cursor)` and allows transformation to another type.
internal final class _Cursor<T> {
    /// The collection's namespace
    let namespace: String
    
    /// The collection this cursor is pointing to
    let collection: Collection
    
    /// The cursor's identifier that allows us to fetch more data from the server
    fileprivate var cursorID: Int
    
    /// The amount of Documents to receive each time from the server
    fileprivate let chunkSize: Int32
    
    var logger: FrameworkLogger {
        return self.collection.database.server.logger
    }
    
    // documents already received by the server
    fileprivate var data: [T]
    
    fileprivate var position = 0
    
    /// A closure that transforms a document to another type if possible, otherwise `nil`
    typealias Transformer = (Document) throws -> (T?)
    
    /// The transformer used for this cursor
    let transform: Transformer
    
    /// This initializer creates a base cursor from a reply message
    internal convenience init?(namespace: String, collection: Collection, reply: ServerReply, chunkSize: Int32, transform: @escaping Transformer) throws {
        self.init(namespace: namespace, collection: collection, cursorID: reply.cursorID, initialData: try reply.documents.flatMap(transform), chunkSize: chunkSize, transform: transform)
    }
    
    /// This initializer creates a base cursor from a replied Document
    internal convenience init(cursorDocument cursor: Document, collection: Collection, chunkSize: Int32, transform: @escaping Transformer) throws {
        guard let cursorID = Int(cursor["id"]), let namespace = String(cursor["ns"]), let firstBatch = Document(cursor["firstBatch"]) else {
            throw MongoError.cursorInitializationError(cursorDocument: cursor)
        }
        
        self.init(namespace: namespace, collection: collection, cursorID: cursorID, initialData: try firstBatch.arrayValue.flatMap{ Document($0) }.flatMap(transform), chunkSize: chunkSize, transform: transform)
    }
    
    /// This initializer creates a base cursor from provided specific data
    internal init(namespace: String, collection: Collection, cursorID: Int, initialData: [T], chunkSize: Int32, transform: @escaping Transformer) {
        self.namespace = namespace
        self.collection = collection
        self.cursorID = cursorID
        self.data = initialData
        self.chunkSize = chunkSize
        self.transform = transform
    }
    
    /// Transforms the base cursor to a new cursor of a new type
    ///
    /// The transformer will get `B` as input and is expected to return `T?` for the new type.
    ///
    /// This allows you to easily map a Document cursor returned by MongoKitten to a new type like your model.
    internal init<B>(base: _Cursor<B>, transform: @escaping (B) throws -> (T?)) throws {
        self.namespace = base.namespace
        self.collection = base.collection
        self.cursorID = base.cursorID
        self.chunkSize = base.chunkSize
        self.transform = {
            if let bValue = try base.transform($0) {
                return try transform(bValue)
            } else {
                return nil
            }
        }
        self.data = try base.data.flatMap(transform)
    }
    
    /// Gets more information and puts it in the buffer
    fileprivate func getMore() throws {
        do {
            if collection.database.server.serverData?.maxWireVersion ?? 0 >= 4 {
                let reply = try collection.database.execute(command: [
                    "getMore": Int(self.cursorID),
                    "collection": collection.name,
                    "batchSize": Int32(chunkSize)
                    ], writing: false)
                
                let documents = [Primitive](reply.documents.first?["cursor"]["nextBatch"]) ?? []
                for value in documents {
                    if let doc = try transform(Document(value) ?? [:]) {
                        self.data.append(doc)
                    }
                }
                
                self.cursorID = Int(reply.documents.first?["cursor"]["id"]) ?? -1
            } else {
                let connection = try collection.database.server.reserveConnection(authenticatedFor: self.collection.database)
                
                defer {
                    collection.database.server.returnConnection(connection)
                }
                
                let request = Message.GetMore(requestID: collection.database.server.nextMessageID(), namespace: namespace, numberToReturn: chunkSize, cursor: cursorID)
                
                let reply = try collection.database.server.sendAndAwait(message: request, overConnection: connection)
                
                self.data += try reply.documents.flatMap(transform)
                self.cursorID = reply.cursorID
            }
        } catch {
            logger.error("Could not fetch extra data from the cursor due to error: \(error)")
            collection.database.server.cursorErrorHandler(error)
        }
    }
    
    /// When deinitializing we're killing the cursor on the server as well
    deinit {
        if cursorID != 0 {
            do {
                let connection = try collection.database.server.reserveConnection(authenticatedFor: self.collection.database)
                
                defer {
                    collection.database.server.returnConnection(connection)
                }
                
                let killCursorsMessage = Message.KillCursors(requestID: collection.database.server.nextMessageID(), cursorIDs: [self.cursorID])
                try collection.database.server.send(message: killCursorsMessage, overConnection: connection)
            } catch {
                collection.database.server.cursorErrorHandler(error)
            }
        }
    }
}

extension _Cursor : Sequence {
    /// Makes an iterator to loop over the data this cursor points to from (for example) a loop
    /// - returns: The iterator
    internal func makeIterator() -> AnyIterator<T> {
        return AnyIterator {
            while true {
                do {
                    return try self.next()
                } catch {}
            }
        }
    }
    
    /// Allows you to fetch the first next entity in the Cursor
    internal func next() throws -> T? {
        defer { position += 1 }
        
        if position >= self.data.count && self.cursorID != 0 {
            position = 0
            self.data = []
            // Get more data!
            try self.getMore()
        }
        
        return position < self.data.count ? self.data[position] : nil
    }
}

extension _Cursor : CustomStringConvertible {
    /// A description for debugging purposes
    internal var description: String {
        return "MongoKitten.Cursor<\(namespace)>"
    }
}
