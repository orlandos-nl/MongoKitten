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
public final class Cursor<C: Codable>: Async.OutputStream {
    public typealias Output = Document
    
    /// The collection's namespace
    var spec: Reply.Cursor.CursorSpec?

    /// The collection this cursor is pointing to
    let collection: MongoCollection<C>
    
    let databaseConnection: DatabaseConnection

    /// The cursor's identifier that allows us to fetch more data from the server
    fileprivate var cursorID: Int64 = 0

    /// The amount of Documents to receive each time from the server
    fileprivate let chunkSize: Int32 = 100
    
    /// Downstream client and eventloop input stream
    private var downstream: AnyInputStream<Document>?
    
    var pushStream = PushStream<Document>()
    
    var consumedBacklog: Int = 0
    
    var downstreamRequest: UInt = 0

    /// This initializer creates a base cursor from a replied Document
    internal init(collection: MongoCollection<C>, connection: DatabaseConnection) {
        self.databaseConnection = connection
        self.collection = collection
    }
    
    public func output<S>(to inputStream: S) where S : InputStream, Cursor.Output == S.Input {
        pushStream.output(to: inputStream)
    }
    
    func initialize(to spec: Reply.Cursor.CursorSpec) {
        self.spec = spec
        
        for doc in spec.firstBatch {
            pushStream.push(doc)
        }
    }
    
    fileprivate func fetchMore() {
        guard let spec = self.spec, cursorID != 0 else {
            // Prevent cancelling an uninitialized cursor
            if self.spec != nil {
                self.pushStream.close()
            }
            
            return
        }
        
        guard self.databaseConnection.wireProtocol >= 4 else {
            pushStream.error(MongoError.unsupportedFeature("GetMore from cursor"))
            pushStream.close()
            
            return
        }
        
        let command = Commands.GetMore(
            getMore: self.cursorID,
            collection: self.collection,
            batchSize: self.chunkSize
        )
        
        databaseConnection.execute(command, expecting: Reply.GetMore.self) { result, connection in
            defer {
                if result.cursor.id <= 0 {
                    self.pushStream.close()
                }
            }
            
            for doc in result.cursor.nextBatch {
                self.pushStream.push(doc)
            }
            
            self.cursorID = result.cursor.id
        }.catch { error in
            self.downstream?.error(error)
            self.pushStream.close()
        }
    }
    
    /// When deinitializing we're killing the cursor on the server as well
    deinit {
        let killCursors = Commands.KillCursors(
            killCursors: self.collection,
            cursors: [ self.cursorID ]
        )
        
        // TODO: Exclusive access crash
        //_ = databaseConnection.execute(killCursors) { _, _ in }
        self.cursorID = 0
    }
}

extension Commands {
    struct GetMore<C: Codable>: Command {
        var targetCollection: MongoCollection<C> {
            return collection
        }
        
        static var writing: Bool { return false }
        static var emitsCursor: Bool { return false }
        
        var getMore: Int64
        var collection: MongoCollection<C>
        var batchSize: Int32
    }
    
    struct KillCursors<C: Codable>: Command {
        var targetCollection: MongoCollection<C> {
            return killCursors
        }
        
        static var writing: Bool { return false }
        static var emitsCursor: Bool { return false }
        
        var killCursors: MongoCollection<C>
        var cursors: [Int64]
    }
}

extension Reply {
    struct GetMore : Decodable {
        struct CursorData: Decodable {
            var nextBatch: [Document]
            var id: Int64
        }
        
        var cursor: CursorData
    }
}
