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
    let collection: String
    
    // The database to query to
    let database: Database
    
    /// The cursor's identifier that allows us to fetch more data from the server
    fileprivate var cursorID: Int
    
    /// The amount of Documents to receive each time from the server
    fileprivate let chunkSize: Int32
    
    // documents already received by the server
    var data: [T]
    
    // Cache of `data.count`
    // Used to prevent a crash when reading from a cursor that's receiving data
    fileprivate var dataCount: Int
    
    fileprivate let connection: Connection
    
    fileprivate var position = 0
    
    public var strategy: CursorStrategy? = nil
    
    fileprivate var currentFetch: Future<Void>? = nil
    
    /// A closure that transforms a document to another type if possible, otherwise `nil`
    typealias Transformer = (Document) throws -> (T?)
    
    /// The transformer used for this cursor
    let transform: Transformer
    
    /// This initializer creates a base cursor from a reply message
    internal convenience init(namespace: String, collection: String, database: Database, connection: Connection, reply: ServerReply, chunkSize: Int32, transform: @escaping Transformer) throws {
        self.init(namespace: namespace, collection: collection, database: database, connection: connection, cursorID: reply.cursorID, initialData: try reply.documents.flatMap(transform), chunkSize: chunkSize, transform: transform)
    }
    
    /// This initializer creates a base cursor from a replied Document
    internal convenience init(cursorDocument cursor: Document, collection: String, database: Database, connection: Connection, chunkSize: Int32, transform: @escaping Transformer) throws {
        guard let cursorID = Int(cursor["id"]), let namespace = String(cursor["ns"]), let firstBatch = Document(cursor["firstBatch"]) else {
            throw MongoError.cursorInitializationError(cursorDocument: cursor)
        }
        
        self.init(namespace: namespace, collection: collection, database: database, connection: connection, cursorID: cursorID, initialData: try firstBatch.arrayRepresentation.flatMap{ Document($0) }.flatMap(transform), chunkSize: chunkSize, transform: transform)
    }
    
    /// This initializer creates a base cursor from provided specific data
    internal init(namespace: String, collection: String, database: Database, connection: Connection, cursorID: Int, initialData: [T], chunkSize: Int32, transform: @escaping Transformer) {
        self.namespace = namespace
        self.collection = collection
        self.database = database
        self.cursorID = cursorID
        self.connection = connection
        self.data = initialData
        self.chunkSize = chunkSize
        self.transform = transform
        self.dataCount = initialData.count
    }
    
    /// Transforms the base cursor to a new cursor of a new type
    ///
    /// The transformer will get `B` as input and is expected to return `T?` for the new type.
    ///
    /// This allows you to easily map a Document cursor returned by MongoKitten to a new type like your model.
    internal init<B>(base: Cursor<B>, transform: @escaping (B) throws -> (T?)) throws {
        self.namespace = base.namespace
        self.collection = base.collection
        self.database = base.database
        self.cursorID = base.cursorID
        self.chunkSize = base.chunkSize
        self.connection = try self.database.server.reserveConnection(authenticatedFor: self.database)
        self.transform = {
            if let bValue = try base.transform($0) {
                return try transform(bValue)
            } else {
                return nil
            }
        }
        self.data = try base.data.flatMap(transform)
        self.dataCount = base.dataCount
    }

    var fetching: Bool = false
    
    /// Gets more information and puts it in the buffer
    @discardableResult
    fileprivate func getMore() throws -> Future<Void> {
        return Future {
            do {
                if self.database.server.serverData?.maxWireVersion ?? 0 >= 4 {
                    let reply = try self.database.execute(command: [
                        "getMore": Int(self.cursorID) as Int,
                        "collection": self.collection,
                        "batchSize": Int32.init(self.chunkSize)
                        ], using: self.connection).await()
                    
                    let documents = [Primitive](reply.documents.first?["cursor"]["nextBatch"]) ?? []
                    
                    try cursorMutationsQueue.sync {
                        for value in documents {
                            if let doc = try self.transform(Document(value) ?? [:]) {
                                self.data.append(doc)
                            }
                        }
            
                        self.cursorID = Int(reply.documents.first?["cursor"]["id"]) ?? -1
                        self.dataCount = self.data.count
                    }
                } else {
                    let request = Message.GetMore(requestID: self.database.server.nextMessageID(), namespace: self.namespace, numberToReturn: self.chunkSize, cursor: self.cursorID)
                    
                    let reply = try self.database.server.sendAsync(message: request, overConnection: self.connection).await()
                    
                    try cursorMutationsQueue.sync {
                        self.data += try reply.documents.flatMap(self.transform)
                        self.cursorID = reply.cursorID
                    }
                }
            } catch {
                log.error("Could not fetch extra data from the cursor due to error: \(error)")
                self.database.server.cursorErrorHandler(error)
            }
        }
    }
    
    fileprivate func nextEntity() throws -> T? {
        defer { position += 1 }
        
        strategy: switch strategy ?? self.database.server.cursorStrategy {
        case .lazy:
            if position >= dataCount && self.cursorID != 0 {
                position = 0
                cursorMutationsQueue.sync {
                    self.data = []
                }
                // Get more data!
                _ = try self.getMore().await()
            }
        case .intelligent(let dataSets):
            guard self.dataCount - position < dataSets * Int(self.chunkSize) else {
                break strategy
            }
            
            fallthrough
        case .aggressive:
            if let currentFetch = currentFetch {
                if position == self.dataCount {
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
            } else if position == self.dataCount && self.cursorID != 0 {
                _ = try self.getMore().await()
            } else if self.cursorID != 0 {
                self.currentFetch = try self.getMore()
            }
        }
        
        if position > Int(self.chunkSize) {
            position -= Int(self.chunkSize)
            
            cursorMutationsQueue.sync {
                self.data.removeFirst(Int(self.chunkSize))
                self.dataCount -= Int(self.chunkSize)
            }
        }
        
        return cursorMutationsQueue.sync {
            if position < self.dataCount {
                return self.data[position]
            }
            
            return nil
        }
    }
    
    /// An efficient and lazy asynchronous forEach operation specialized for MongoDB.
    ///
    /// Designed to throw errors in the case of a cursor failure, unlike normal `for .. in cursor` operations
    @discardableResult
    public func forEach(_ body: @escaping (T) throws -> Void) throws -> Future<Void> {
        return Future<Void> {
            while let entity = try self.nextEntity() {
                try body(entity)
            }
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
                    self.database.server.returnConnection(connection)
                }
                
                let killCursorsMessage = Message.KillCursors(requestID: self.database.server.nextMessageID(), cursorIDs: [self.cursorID])
                try self.database.server.send(message: killCursorsMessage, overConnection: connection)
            } catch {
                self.database.server.cursorErrorHandler(error)
            }
        }
        
        self.database.server.returnConnection(connection)
    }
}

extension Cursor : CustomStringConvertible {
    /// A description for debugging purposes
    public var description: String {
        return "MongoKitten.Cursor<\(namespace)>"
    }
}
