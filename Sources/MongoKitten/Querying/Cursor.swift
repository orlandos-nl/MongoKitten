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
public final class Cursor<T> {
    /// The collection's namespace
    public let namespace: String
    
    /// The collection this cursor is pointing to
    public let collection: Collection
    
    /// The cursor's identifier that allows us to fetch more data from the server
    fileprivate var cursorID: Int64
    
    /// The amount of Documents to receive each time from the server
    fileprivate let chunkSize: Int32
    
    var logger: FrameworkLogger {
        return self.collection.database.server.logger
    }
    
    // documents already received by the server
    fileprivate var data: [T]
    
    fileprivate var position = 0
    
    /// A closure that transforms a document to another type if possible, otherwise `nil`
    typealias Transformer = (Document) -> (T?)
    
    /// The transformer used for this cursor
    let transform: Transformer
    
    /// This initializer creates a base cursor from a reply message
    internal convenience init?(namespace: String, collection: Collection, reply: Message, chunkSize: Int32, transform: @escaping Transformer) {
        guard case .Reply(_, _, _, let cursorID, _, _, let documents) = reply else {
            return nil
        }
        
        self.init(namespace: namespace, collection: collection, cursorID: cursorID, initialData: documents.flatMap(transform), chunkSize: chunkSize, transform: transform)
    }
    
    /// This initializer creates a base cursor from a replied Document
    internal convenience init(cursorDocument cursor: Document, collection: Collection, chunkSize: Int32, transform: @escaping Transformer) throws {
        guard let cursorID = cursor["id"] as Int64?, let namespace = cursor["ns"] as String?, let firstBatch = cursor["firstBatch"] as Document? else {
            throw MongoError.cursorInitializationError(cursorDocument: cursor)
        }
        
        self.init(namespace: namespace, collection: collection, cursorID: cursorID, initialData: firstBatch.arrayValue.flatMap{$0.documentValue}.flatMap(transform), chunkSize: chunkSize, transform: transform)
    }
    
    /// This initializer creates a base cursor from provided specific data
    internal init(namespace: String, collection: Collection, cursorID: Int64, initialData: [T], chunkSize: Int32, transform: @escaping Transformer) {
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
    public init<B>(base: Cursor<B>, transform: @escaping (B) -> (T?)) {
        self.namespace = base.namespace
        self.collection = base.collection
        self.cursorID = base.cursorID
        self.chunkSize = base.chunkSize
        self.transform = {
            if let bValue = base.transform($0) {
                return transform(bValue)
            } else {
                return nil
            }
        }
        self.data = base.data.flatMap(transform)
    }
    
    /// Gets more information and puts it in the buffer
    fileprivate func getMore() {
        do {
            if collection.database.server.serverData?.maxWireVersion ?? 0 >= 4 {
                let reply = try collection.database.execute(command: [
                    "getMore": Int64(self.cursorID),
                    "collection": collection.name,
                    "batchSize": Int32(chunkSize)
                    ], writing: false)
                
                guard case .Reply(_, _, _, _, _, _, let resultDocs) = reply else {
                    logger.error("Incorrect Cursor reply received")
                    throw InternalMongoError.incorrectReply(reply: reply)
                }
                
                let documents = resultDocs.first?["cursor", "nextBatch"] as Document? ?? []
                for value in documents.arrayValue {
                    if let doc = transform(value.documentValue ?? [:]) {
                        self.data.append(doc)
                    }
                }
                
                self.cursorID = resultDocs.first?["cursor", "id"] as Int64? ?? -1
            } else {
                let connection = try collection.database.server.reserveConnection(authenticatedFor: self.collection.database)
                
                defer {
                    collection.database.server.returnConnection(connection)
                }
                
                let request = Message.GetMore(requestID: collection.database.server.nextMessageID(), namespace: namespace, numberToReturn: chunkSize, cursor: cursorID)
                
                let reply = try collection.database.server.sendAndAwait(message: request, overConnection: connection)
                
                guard case .Reply(_, _, _, let cursorID, _, _, let documents) = reply else {
                    logger.error("Incorrect Cursor reply received")
                    throw InternalMongoError.incorrectReply(reply: reply)
                }
                
                self.data += documents.flatMap(transform)
                self.cursorID = cursorID
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

extension Cursor : Sequence {
    /// Makes an iterator to loop over the data this cursor points to from (for example) a loop
    /// - returns: The iterator
    public func makeIterator() -> AnyIterator<T> {
        return AnyIterator {
            return self.next()
        }
    }
    
    /// Allows you to fetch the first next entity in the Cursor
    public func next() -> T? {
        defer { position += 1 }
        
        if position >= self.data.count && self.cursorID != 0 {
            position = 0
            self.data = []
            // Get more data!
            self.getMore()
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
