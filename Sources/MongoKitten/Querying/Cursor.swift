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

public struct CursorStrategy {
    init() {}
    
    public static func lazy() -> CursorStrategy {
        return CursorStrategy()
    }
    
    public static func aggressive() -> CursorStrategy {
        return CursorStrategy()
    }
    
    public static func intelligent(bufferChunks: Int) -> CursorStrategy {
        return CursorStrategy()
    }
}

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
    let collection: String

    /// The cursor's identifier that allows us to fetch more data from the server
    fileprivate var cursorID: Int

    /// The amount of Documents to receive each time from the server
    fileprivate let chunkSize: Int32

    fileprivate let connection: DatabaseConnection

    public var strategy: CursorStrategy? = nil
    
    var currentBatch = [Document]()
    
    var draining = false
    
    let stream = BasicStream<Output>()

    /// This initializer creates a base cursor from a replied Document
    internal init(cursor: Reply.Cursor.CursorSpec, collection: String, database: Database, connection: DatabaseConnection, chunkSize: Int32) throws {
        self.chunkSize = chunkSize
        self.connection = connection
        self.collection = collection
        self.namespace = cursor.ns
        self.cursorID = cursor.id
        self.currentBatch = cursor.firstBatch
    }
    
    public func start() {
        draining = true
        
        for doc in currentBatch {
            stream.onInput(doc)
        }
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
    
//    var fetching: Bool = false
//
//    /// Gets more information and puts it in the buffer
//    @discardableResult
//    fileprivate func getMore() throws -> Future<Void> {
//        do {
//            if self.database.server.serverData?.maxWireVersion ?? 0 >= 4 {
//                let reply = try self.database.execute(command: [
//                    "getMore": Int(self.cursorID) as Int,
//                    "collection": self.collection,
//                    "batchSize": Int32.init(self.chunkSize)
//                    ], using: self.connection).blockingAwait(timeout: .seconds(3))
//
//                let documents = [Primitive](reply.documents.first?["cursor"]["nextBatch"]) ?? []
//
//                try cursorMutationsQueue.sync {
//                    for value in documents {
//                        if let doc = try self.transform(Document(value) ?? [:]) {
//                            self.data.append(doc)
//                        }
//                    }
//
//                    self.cursorID = Int(reply.documents.first?["cursor"]["id"]) ?? -1
//                    self.dataCount = self.data.count
//                }
//            } else {
//                let request = Message.GetMore(requestID: self.database.server.nextMessageID(), namespace: self.namespace, numberToReturn: self.chunkSize, cursor: self.cursorID)
//
//                let reply = try self.database.server.sendAsync(message: request, overConnection: self.connection).blockingAwait(timeout: .seconds(3))
//
//                try cursorMutationsQueue.sync {
//                    self.data += try reply.documents.flatMap(self.transform)
//                    self.cursorID = reply.cursorID
//                }
//            }
//        }
//    }
//
//    fileprivate func nextEntity() throws -> T? {
//        defer { position += 1 }
//
//        strategy: switch strategy ?? self.database.server.cursorStrategy {
//        case .lazy:
//            if position >= dataCount && self.cursorID != 0 {
//                position = 0
//                cursorMutationsQueue.sync {
//                    self.data = []
//                }
//                // Get more data!
//                _ = try self.getMore().blockingAwait(timeout: .seconds(3))
//            }
//        case .intelligent(let dataSets):
//            guard self.dataCount - position < dataSets * Int(self.chunkSize) else {
//                break strategy
//            }
//
//            fallthrough
//        case .aggressive:
//            if let currentFetch = currentFetch {
//                if position == self.dataCount {
//                    guard !currentFetch.isCompleted else {
//                        break strategy
//                    }
//                } else if !currentFetch.isCompleted {
//                    break strategy
//                }
//
//                defer {
//                    self.currentFetch = nil
//                }
//
//                _ = try currentFetch.blockingAwait(timeout: .seconds(3))
//            } else if position == self.dataCount && self.cursorID != 0 {
//                _ = try self.getMore().blockingAwait(timeout: .seconds(3))
//            } else if self.cursorID != 0 {
//                self.currentFetch = try self.getMore()
//            }
//        }
//
//        if position > Int(self.chunkSize) {
//            position -= Int(self.chunkSize)
//
//            cursorMutationsQueue.sync {
//                self.data.removeFirst(Int(self.chunkSize))
//                self.dataCount -= Int(self.chunkSize)
//            }
//        }
//
//        return cursorMutationsQueue.sync {
//            if position < self.dataCount {
//                return self.data[position]
//            }
//
//            return nil
//        }
//    }
//
//    /// When deinitializing we're killing the cursor on the server as well
//    deinit {
//        if cursorID != 0 {
//            do {
//                defer {
//                    self.database.server.returnConnection(connection)
//                }
//
//                let killCursorsMessage = Message.KillCursors(requestID: self.database.server.nextMessageID(), cursorIDs: [self.cursorID])
//                try self.database.server.send(message: killCursorsMessage, overConnection: connection)
//            } catch {
//                self.database.server.cursorErrorHandler(error)
//            }
//        }
//
//        self.database.server.returnConnection(connection)
//    }
}

extension Cursor : CustomStringConvertible {
    /// A description for debugging purposes
    public var description: String {
        return "MongoKitten.Cursor<\(namespace)>"
    }
}
