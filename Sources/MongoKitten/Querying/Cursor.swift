////
//// This source file is part of the MongoKitten open source project
////
//// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
//// Licensed under MIT
////
//// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
//// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
////
//
//import Dispatch
//import Foundation
import BSON
import Async
//import ExtendedJSON

extension Reply {
    struct Cursor: Decodable {
        struct CursorSpec: Decodable {
            var id: Int
            var ns: String
            var firstBatch: [Document]
        }
        
        var ok: Int
        var cursor: CursorSpec
    }
}

///// A Cursor is a pointer to a sequence/collection of Documents on the MongoDB server.
/////
///// It can be looped over using a `for let document in cursor` loop like any other sequence.
/////
///// It can be transformed into an array with `Array(cursor)` and allows transformation to another type.
public final class Cursor: Async.OutputStream, ConnectionContext {
    public typealias Output = Document
    
    /// The collection's namespace
    let namespace: String

    /// The collection this cursor is pointing to
    let collection: MongoCollection
    
    let databaseConnection: DatabaseConnection

    /// The cursor's identifier that allows us to fetch more data from the server
    fileprivate var cursorID: Int

    /// The amount of Documents to receive each time from the server
    fileprivate let chunkSize: Int32
    
    /// Downstream client and eventloop input stream
    private var downstream: AnyInputStream<Document>?
    
    var backlog = [Document]()
    
    var consumedBacklog: Int = 0
    
    var downstreamRequest: UInt = 0

    /// This initializer creates a base cursor from a replied Document
    internal init(cursor: Reply.Cursor.CursorSpec, collection: MongoCollection, database: Database, connection: DatabaseConnection, chunkSize: Int32) throws {
        self.chunkSize = chunkSize
        self.databaseConnection = connection
        self.collection = collection
        self.namespace = cursor.ns
        self.cursorID = cursor.id
        self.backlog = cursor.firstBatch
    }
    
    public func output<S>(to inputStream: S) where S : InputStream, Cursor.Output == S.Input {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }
    
    public func connection(_ event: ConnectionEvent) {
        switch event {
        case.request(let count):
            self.downstreamRequest += count
            
            flushBacklog()
        case .cancel:
            self.downstreamRequest = 0
            /// handle downstream canceling output requests
            downstream?.close()
        }
    }
    
    fileprivate func flushBacklog() {
        defer {
            self.backlog.removeFirst(consumedBacklog)
        }
        
        while backlog.count > consumedBacklog, downstreamRequest > 0 {
            let doc = self.backlog[self.consumedBacklog]
            consumedBacklog += 1
            
            downstream?.next(doc)
        }
        
        if consumedBacklog >= backlog.count {
            fetchMore()
        }
    }
    
    fileprivate func fetchMore() {
        if cursorID == 0 {
            self.cancel()
            return
        }
        
        if self.databaseConnection.wireProtocol >= 4 {
            let command = Commands.GetMore(
                getMore: self.cursorID,
                collection: self.collection,
                batchSize: self.chunkSize
            )
            
            databaseConnection.execute(command, expecting: Reply.GetMore.self) { result, connection in
                defer {
                    if result.cursor.id <= 0 {
                        self.cancel()
                    }
                }
                
                self.backlog = result.cursor.nextBatch
                self.cursorID = result.cursor.id
                self.flushBacklog()
            }.catch { error in
                self.downstream?.error(error)
                self.cancel()
            }
        } else  {
            let request = Message.GetMore(requestID: self.databaseConnection.nextRequestId, namespace: self.namespace, numberToReturn: self.chunkSize, cursor: self.cursorID)
            
            self.databaseConnection.send(message: request).do { reply in
                self.backlog = reply.documents
                self.cursorID = reply.cursorID
                
                self.flushBacklog()
            }.catch { error in
                self.downstream?.error(error)
                self.cancel()
            }
        }
    }
    
    /// When deinitializing we're killing the cursor on the server as well
    deinit {
        if cursorID != 0 {
            let killCursorsMessage = Message.KillCursors(requestID: self.databaseConnection.nextRequestId, cursorIDs: [self.cursorID])
            _ = self.databaseConnection.send(message: killCursorsMessage)
        }
    }
}

extension Commands {
    struct GetMore: Command {
        var targetCollection: MongoCollection {
            return collection
        }
        
        static let writing: Bool = false
        static let emitsCursor: Bool = false
        
        var getMore: Int
        var collection: MongoCollection
        var batchSize: Int32
    }
}

extension Reply {
    struct GetMore : Decodable {
        struct CursorData: Decodable {
            var nextBatch: [Document]
            var id: Int
        }
        
        var cursor: CursorData
    }
}

extension Cursor : CustomStringConvertible {
    /// A description for debugging purposes
    public var description: String {
        return "MongoKitten.Cursor<\(namespace)>"
    }
}
