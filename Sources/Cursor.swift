//
//  Cursor.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 22-02-16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public final class Cursor<T> {
    public let namespace: String
    public let server: Server
    private var cursorID: Int64
    private let chunkSize: Int32
    
    // documents already received by the server
    private var data: [T]
    
    typealias Transformer = (Document) -> (T?)
    let transform: Transformer
    
    /// If firstDataSet is nil, reply.documents will be passed to transform as initial data
    internal convenience init?(namespace: String, server: Server, reply: Message, chunkSize: Int32, transform: Transformer) {
        guard case .Reply(_, _, _, let cursorID, _, _, let documents) = reply else {
            return nil
        }
        
        self.init(namespace: namespace, server: server, cursorID: cursorID, initialData: documents.flatMap(transform), chunkSize: chunkSize, transform: transform)
    }
    
    internal convenience init(cursorDocument cursor: Document, server: Server, chunkSize: Int32, transform: Transformer) throws {
        guard let cursorID = cursor["id"]?.int64Value, namespace = cursor["ns"]?.stringValue, firstBatch = cursor["firstBatch"]?.documentValue else {
            throw MongoError.CursorInitializationError(cursorDocument: cursor)
        }
        
        self.init(namespace: namespace, server: server, cursorID: cursorID, initialData: firstBatch.arrayValue.flatMap{$0.documentValue}.flatMap(transform), chunkSize: chunkSize, transform: transform)
    }
    
    internal init(namespace: String, server: Server, cursorID: Int64, initialData: [T], chunkSize: Int32, transform: Transformer) {
        self.namespace = namespace
        self.server = server
        self.cursorID = cursorID
        self.data = initialData
        self.chunkSize = chunkSize
        self.transform = transform
    }
    
    internal init<B>(base: Cursor<B>, transform: (B) -> (T?)) {
        self.namespace = base.namespace
        self.server = base.server
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
    
    private func getMore() {
        do {
            let request = Message.GetMore(requestID: server.getNextMessageID(), namespace: namespace, numberToReturn: chunkSize, cursor: cursorID)
            let requestId = try server.sendMessage(request)
            let reply = try server.awaitResponse(requestId)
            
            guard case .Reply(_, _, _, let cursorID, _, _, let documents) = reply else {
                throw InternalMongoError.IncorrectReply(reply: reply)
            }
            
            self.data += documents.flatMap(transform)
            self.cursorID = cursorID
        } catch {
            print("Error fetching extra data from the server in \(self) with error: \(error)")
            abort()
        }
    }
    
    deinit {
        if cursorID != 0 {
            do {
                let killCursorsMessage = Message.KillCursors(requestID: server.getNextMessageID(), cursorIDs: [self.cursorID])
                try server.sendMessage(killCursorsMessage)
            } catch {
                print("Error while cleaning up MongoDB cursor \(self): \(error)")
            }
        }
    }
}

extension Cursor : SequenceType {
    public func generate() -> AnyGenerator<T> {
        return AnyGenerator {
            if self.data.isEmpty && self.cursorID != 0 {
                // Get more data!
                self.getMore()
            }
            
            return self.data.isEmpty ? nil : self.data.removeFirst()
        }
    }
}