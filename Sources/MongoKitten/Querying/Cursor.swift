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
import BSON
import Schrodinger

public enum CursorStrategy {
    case lazy
    case agressive
}

/// A Cursor is a pointer to a sequence/collection of Documents on the MongoDB server.
///
/// It can be looped over using a `for let document in cursor` loop like any other sequence.
///
/// It can be transformed into an array with `Array(cursor)` and allows transformation to another type.
public final class Cursor<T> {
    /// The collection's namespace
    let namespace: String
    
    /// The collection this cursor is pointing to
    let collection: Collection
    
    /// The cursor's identifier that allows us to fetch more data from the server
    fileprivate var cursorID: Int
    
    /// The amount of Documents to receive each time from the server
    fileprivate let chunkSize: Int32
    
    // documents already received by the server
    fileprivate var data: [T]
    
    fileprivate let connection: Connection
    
    fileprivate var position = 0
    
    public var strategy: CursorStrategy? = nil
    
    /// A closure that transforms a document to another type if possible, otherwise `nil`
    typealias Transformer = (Document) throws -> (T?)
    
    /// The transformer used for this cursor
    let transform: Transformer
    
    /// This initializer creates a base cursor from a reply message
    internal convenience init?(namespace: String, collection: Collection, connection: Connection, reply: ServerReply, chunkSize: Int32, transform: @escaping Transformer) throws {
        self.init(namespace: namespace, collection: collection, connection: connection, cursorID: reply.cursorID, initialData: try reply.documents.flatMap(transform), chunkSize: chunkSize, transform: transform)
    }
    
    /// This initializer creates a base cursor from a replied Document
    internal convenience init(cursorDocument cursor: Document, collection: Collection, connection: Connection, chunkSize: Int32, transform: @escaping Transformer) throws {
        guard let cursorID = Int(cursor["id"]), let namespace = String(cursor["ns"]), let firstBatch = Document(cursor["firstBatch"]) else {
            throw MongoError.cursorInitializationError(cursorDocument: cursor)
        }
        
        self.init(namespace: namespace, collection: collection, connection: connection, cursorID: cursorID, initialData: try firstBatch.arrayValue.flatMap{ Document($0) }.flatMap(transform), chunkSize: chunkSize, transform: transform)
    }
    
    /// This initializer creates a base cursor from provided specific data
    internal init(namespace: String, collection: Collection, connection: Connection, cursorID: Int, initialData: [T], chunkSize: Int32, transform: @escaping Transformer) {
        self.namespace = namespace
        self.collection = collection
        self.cursorID = cursorID
        self.connection = connection
        self.data = initialData
        self.chunkSize = chunkSize
        self.transform = transform
    }
    
    /// Transforms the base cursor to a new cursor of a new type
    ///
    /// The transformer will get `B` as input and is expected to return `T?` for the new type.
    ///
    /// This allows you to easily map a Document cursor returned by MongoKitten to a new type like your model.
    internal init<B>(base: Cursor<B>, transform: @escaping (B) throws -> (T?)) throws {
        self.namespace = base.namespace
        self.collection = base.collection
        self.cursorID = base.cursorID
        self.chunkSize = base.chunkSize
        self.connection = try collection.database.server.reserveConnection(authenticatedFor: self.collection.database)
        self.transform = {
            if let bValue = try base.transform($0) {
                return try transform(bValue)
            } else {
                return nil
            }
        }
        self.data = try base.data.flatMap(transform)
    }

    var fetching: Bool = false
    
    /// Gets more information and puts it in the buffer
    fileprivate func getMore() throws -> Promise<Void> {
        return async {
            do {
                if self.collection.database.server.serverData?.maxWireVersion ?? 0 >= 4 {
                    try self.collection.database
                    let reply = try self.collection.database.execute(command: [
                        "getMore": Int(self.cursorID),
                        "collection": self.collection.name,
                        "batchSize": Int32(self.chunkSize)
                        ], writing: false)
                    
                    let documents = [Primitive](reply.documents.first?["cursor"]["nextBatch"]) ?? []
                    for value in documents {
                        if let doc = try self.transform(Document(value) ?? [:]) {
                            self.data.append(doc)
                        }
                    }
                    
                    self.cursorID = Int(reply.documents.first?["cursor"]["id"]) ?? -1
                } else {
                    let request = Message.GetMore(requestID: self.collection.database.server.nextMessageID(), namespace: self.namespace, numberToReturn: self.chunkSize, cursor: self.cursorID)
                    
                    let reply = try self.collection.database.server.sendAndAwait(message: request, overConnection: self.connection)
                    
                    self.data += try reply.documents.flatMap(self.transform)
                    self.cursorID = reply.cursorID
                }
            } catch {
                log.error("Could not fetch extra data from the cursor due to error: \(error)")
                self.collection.database.server.cursorErrorHandler(error)
            }
        }
    }
    
    public func flatMap<B>(transform: @escaping (T) throws -> (B?)) throws -> Cursor<B> {
        return try Cursor<B>(base: self, transform: transform)
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
        
        self.collection.database.server.returnConnection(connection)
    }
}

extension Cursor : Sequence, IteratorProtocol {
    /// Makes an iterator to loop over the data this cursor points to from (for example) a loop
    /// - returns: The iterator
    public func makeIterator() -> Cursor<T> {
        return self
    }
    
    public func next() -> T? {
        defer { position += 1 }
        
        switch strategy ?? collection.database.server.cursorStrategy {
        case .lazy:
            if position >= self.data.count && self.cursorID != 0 {
                position = 0
                self.data = []
                // Get more data!
                do {
                    try self.getMore()
                } catch {
                    return nil
                }
            }
        case .agressive:
            do {
                try self.getMore()
            } catch { }
            
            if position > 100 {
                position -= 100
                self.data.removeFirst(100)
            }
        }
        
        return position < self.data.count ? self.data[position] : nil
    }
}

extension Cursor : CustomStringConvertible {
    /// A description for debugging purposes
    public var description: String {
        return "MongoKitten.Cursor<\(namespace)>"
    }
}
