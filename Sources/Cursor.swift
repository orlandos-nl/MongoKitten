//
//  Cursor.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 22-02-16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public class Cursor {
    public let collection: Collection
    private var cursorID: Int64
    private let chunkSize: Int32
    
    // documents already received by the server
    private var data: [Document]
    
    internal init(collection: Collection, reply: ReplyMessage, chunkSize: Int32) {
        self.collection = collection
        self.cursorID = reply.cursorId
        self.data = reply.documents
        self.chunkSize = chunkSize
    }
    
    private func getMore() {
        let server = collection.database.server
        
        do {
            let request = try GetMoreMessage(collection: collection, cursorID: cursorID, numberToReturn: chunkSize)
            let requestId = try server.sendMessageSync(request)
            let reply = try server.awaitResponse(requestId)
            self.data += reply.documents
            self.cursorID = reply.cursorId
        } catch {
            print("Error fetching extra data from the server in \(self) with error: \(error)")
        }
    }
    
    deinit {
        if cursorID != 0 {
            do {
                let killCursorsMessage = try KillCursorsMessage(collection: collection, cursorIDs: [self.cursorID])
                try collection.database.server.sendMessageSync(killCursorsMessage)
            } catch {
                print("Error while cleaning up MongoDB cursor \(self): \(error)")
            }
        }
    }
}

extension Cursor : SequenceType {
    public func generate() -> AnyGenerator<Document> {
        return AnyGenerator {
            if self.data.isEmpty {
                // Get more data!
                self.getMore()
            }
            
            return self.data.isEmpty ? nil : self.data.removeFirst()
        }
    }
}