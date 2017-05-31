//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Dispatch
import Foundation
import BSON
import Schrodinger
import ExtendedJSON

public enum CursorStrategy {
    case lazy
    case aggressive
    case intelligent(bufferChunks: Int)
}

fileprivate let cursorMutationsQueue = DispatchQueue(label: "org.mongokitten.server.cursorDataFetchQueue", qos: DispatchQoS.userInteractive)

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
    
    fileprivate var currentFetch: ManualPromise<Void>? = nil
    
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
    @discardableResult
    fileprivate func getMore() throws -> Promise<Void> {
        return async(timeoutAfter: .seconds(30)) {
            do {
                if self.collection.database.server.serverData?.maxWireVersion ?? 0 >= 4 {
                    let reply = try self.collection.database.execute(command: [
                        "getMore": Int(self.cursorID),
                        "collection": self.collection.name,
                        "batchSize": Int32(self.chunkSize)
                        ], using: self.connection)
                    
                    let documents = [Primitive](reply.documents.first?["cursor"]["nextBatch"]) ?? []
                    
                    try cursorMutationsQueue.sync {
                        for value in documents {
                            if let doc = try self.transform(Document(value) ?? [:]) {
                                self.data.append(doc)
                            }
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
    
    fileprivate func nextEntity() throws -> T? {
        defer { position += 1 }
        
        strategy: switch strategy ?? collection.database.server.cursorStrategy {
        case .lazy:
            if position >= self.data.count && self.cursorID != 0 {
                position = 0
                self.data = []
                // Get more data!
                _ = try self.getMore().await()
            }
        case .intelligent(let dataSets):
            guard self.data.count - position < dataSets * Int(self.chunkSize) else {
                break strategy
            }
            
            fallthrough
        case .aggressive:
            if let currentFetch = currentFetch {
                if position == self.data.count {
                    guard !currentFetch.isCompleted else {
                        break strategy
                    }
                } else if !currentFetch.isCompleted {
                    break strategy
                }
                
                defer {
                    self.currentFetch = nil
                }
                
                _ = try currentFetch.await()
            } else if position == self.data.count && self.cursorID != 0 {
                _ = try self.getMore().await()
            } else if self.cursorID != 0 {
                self.currentFetch = try self.getMore()
            }
        }
        
        if position > Int(self.chunkSize) {
            position -= Int(self.chunkSize)
            
            cursorMutationsQueue.sync {
                self.data.removeFirst(Int(self.chunkSize))
            }
        }
        
        return cursorMutationsQueue.sync {
            if position < self.data.count {
                return self.data[position]
            }
            
            return nil
        }
    }
    
    /// An efficient and lazy forEach operation specialized for MongoDB.
    ///
    /// Designed to throw errors in the case of a cursor failure, unline normal `for .. in cursor` operations
    public func forEach(_ body: (T) throws -> Void) throws {
        while let entity = try nextEntity() {
            try body(entity)
        }
    }
    
    /// An efficient and lazy flatmap operation specialized for MongoDB
    public func flatMap<B>(transform: @escaping (T) throws -> (B?)) throws -> Cursor<B> {
        return try Cursor<B>(base: self, transform: transform)
    }
    
    /// When deinitializing we're killing the cursor on the server as well
    deinit {
        if cursorID != 0 {
            do {
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
    
    /// Fetches the next entity in the Cursor
    public func next() -> T? {
        do {
            return try nextEntity()
        } catch {
            log.fatal("The cursor broke due to the error: \"\(error)\". The executed operation did not return all results.")
            assertionFailure()
            return nil
        }
    }
}

extension Cursor : CustomStringConvertible {
    /// A description for debugging purposes
    public var description: String {
        return "MongoKitten.Cursor<\(namespace)>"
    }
}
