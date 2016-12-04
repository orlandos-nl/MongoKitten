//
//  Cursor.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 22-02-16.
//  Copyright © 2016 OpenKitten. All rights reserved.
//

import Foundation
import BSON

public final class Cursor<T> {
    public let namespace: String
    public let collection: Collection
    fileprivate var cursorID: Int64
    fileprivate let chunkSize: Int32
    
    // documents already received by the server
    fileprivate var data: [T]
    
    typealias Transformer = (Document) -> (T?)
    let transform: Transformer
    
    /// If firstDataSet is nil, reply.documents will be passed to transform as initial data
    internal convenience init?(namespace: String, collection: Collection, reply: Message, chunkSize: Int32, transform: @escaping Transformer) {
        guard case .Reply(_, _, _, let cursorID, _, _, let documents) = reply else {
            return nil
        }
        
        self.init(namespace: namespace, collection: collection, cursorID: cursorID, initialData: documents.flatMap(transform), chunkSize: chunkSize, transform: transform)
    }
    
    internal convenience init(cursorDocument cursor: Document, collection: Collection, chunkSize: Int32, transform: @escaping Transformer) throws {
        guard let cursorID = cursor["id"] as Int64?, let namespace = cursor["ns"] as String?, let firstBatch = cursor["firstBatch"] as Document? else {
            throw MongoError.cursorInitializationError(cursorDocument: cursor)
        }
        
        self.init(namespace: namespace, collection: collection, cursorID: cursorID, initialData: firstBatch.arrayValue.flatMap{$0.documentValue}.flatMap(transform), chunkSize: chunkSize, transform: transform)
    }
    
    internal init(namespace: String, collection: Collection, cursorID: Int64, initialData: [T], chunkSize: Int32, transform: @escaping Transformer) {
        self.namespace = namespace
        self.collection = collection
        self.cursorID = cursorID
        self.data = initialData
        self.chunkSize = chunkSize
        self.transform = transform
    }
    
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
                    throw InternalMongoError.incorrectReply(reply: reply)
                }
                
                let documents = resultDocs.first?["cursor", "nextBatch"] as Document? ?? []
                for (_, value) in documents {
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
                    throw InternalMongoError.incorrectReply(reply: reply)
                }
                
                self.data += documents.flatMap(transform)
                self.cursorID = cursorID
            }
        } catch {
            collection.database.server.cursorErrorHandler(error)
        }
    }
    
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
    /// Makes an iterator to loop over the data this cursor points to
    /// - returns: The iterator
    public func makeIterator() -> AnyIterator<T> {
        return AnyIterator {
            if self.data.isEmpty && self.cursorID != 0 {
                // Get more data!
                self.getMore()
            }
            
            return self.data.isEmpty ? nil : self.data.removeFirst()
        }
    }
}

extension Cursor : CustomStringConvertible {
    public var description: String {
        return "MongoKitten.Cursor<\(namespace)>"
    }
}
