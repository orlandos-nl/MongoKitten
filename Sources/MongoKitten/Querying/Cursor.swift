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
public final class Cursor: OutputStream, ClosableStream {
    public typealias Output = Document
    
    /// The collection's namespace
    let namespace: String

    /// The collection this cursor is pointing to
    let collection: MongoCollection

    /// The cursor's identifier that allows us to fetch more data from the server
    fileprivate var cursorID: Int

    /// The amount of Documents to receive each time from the server
    fileprivate let chunkSize: Int32

    fileprivate let connection: DatabaseConnection
    
    var fetching = 0
    
    var drained = 0
    
    var currentBatch = [Document]()
    
    var draining = false
    var fullyDrained = false
    
    let stream = BasicStream<Output>()

    /// This initializer creates a base cursor from a replied Document
    internal init(cursor: Reply.Cursor.CursorSpec, collection: MongoCollection, database: Database, connection: DatabaseConnection, chunkSize: Int32) throws {
        self.chunkSize = chunkSize
        self.connection = connection
        self.collection = collection
        self.namespace = cursor.ns
        self.cursorID = cursor.id
        self.currentBatch = cursor.firstBatch
    }
    
    public func start() {
        draining = true
        
        var i = drained
        
        if i >= currentBatch.count {
            return
        }
        
        while i < currentBatch.count {
            stream.onInput(currentBatch[i])
            i += 1
        }
        
        self.currentBatch = []
        
        if self.cursorID == 0 {
            self.close()
        }
        
        i = 0
    }
    
    public func onOutput<I>(_ input: I) where I : InputStream, Cursor.Output == I.Input {
        stream.onOutput(input)
    }
    
    public func close() {
        stream.close()
    }
    
    public func onClose(_ onClose: ClosableStream) {
        stream.onClose(onClose)
    }
    
    @discardableResult
    fileprivate func fetchMore() -> Future<Void> {
        if self.connection.wireProtocol >= 4 {
            let command = Commands.GetMore(
                getMore: self.cursorID,
                collection: self.collection,
                batchSize: self.chunkSize
            )
            
            return connection.execute(command, expecting: Reply.GetMore.self) { result, connection in
                defer {
                    if result.cursor.id <= 0 {
                        self.close()
                    }
                }
                
                for doc in result.cursor.nextBatch {
                    self.stream.onInput(doc)
                }
            }
        } else  {
            let request = Message.GetMore(requestID: self.connection.nextRequestId, namespace: self.namespace, numberToReturn: self.chunkSize, cursor: self.cursorID)
            
            return self.connection.send(message: request).map { reply in
                for doc in reply.documents {
                    self.stream.onInput(doc)
                }
                
                self.cursorID = reply.cursorID
            }
        }
    }
    
    /// When deinitializing we're killing the cursor on the server as well
    deinit {
        if cursorID != 0 {
            let killCursorsMessage = Message.KillCursors(requestID: self.connection.nextRequestId, cursorIDs: [self.cursorID])
            _ = self.connection.send(message: killCursorsMessage).catch(self.stream.onError)
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
