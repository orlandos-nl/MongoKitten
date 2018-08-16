import MongoKitten
import NIO
import Foundation

extension CodingUserInfoKey {
    static let gridFS = CodingUserInfoKey(rawValue: "GridFS")!
}

public class GridFS {
    
    public static let defaultChunkSize = 261_120 // 255 kB
    
    public typealias FileCursor = MappedCursor<FindCursor, File>
    
    let filesCollection: MongoKitten.Collection
    let chunksCollection: MongoKitten.Collection
    
    private var didEnsureIndexes = false
    
    var eventLoop: EventLoop {
        return filesCollection.database.connection.eventLoop
    }
    
    public init(named name: String = "fs", in database: Database) {
        self.filesCollection = database["\(name).files"]
        self.chunksCollection = database["\(name).chunks"]
    }
    
    public func upload(data: Data, id: Primitive = ObjectId(), chunkSize: Int = GridFS.defaultChunkSize) -> EventLoopFuture<Void> {
        var buffer = FileWriter.allocator.buffer(capacity: data.count)
        buffer.write(bytes: data)
        
        let writer = FileWriter(fs: self, fileId: id, chunkSize: GridFS.defaultChunkSize, buffer: buffer)
        return try writer.finalize()
    }
    
    public func find(_ query: Query) -> FileCursor {
        var decoder = BSONDecoder()
        decoder.userInfo = [
            .gridFS: self as Any
        ]
        
        return filesCollection
            .find(query)
            .decode(File.self, using: decoder)
    }
    
    public func findFile(_ query: Query) -> EventLoopFuture<File?> {
        return self.find(query)
            .limit(1)
            .getFirstResult()
    }
    
    public func findFile(byId id: Primitive) -> EventLoopFuture<File?> {
        return self.findFile("_id" == id)
    }
    
    public func deleteFile(byId id: Primitive) -> EventLoopFuture<Void> {
        return EventLoopFuture<Void>.andAll([
            self.filesCollection.deleteAll(where: "_id" == id).map { _ in },
            self.chunksCollection.deleteAll(where: "files_id" == id).map { _ in }
            ], eventLoop: eventLoop)
    }
    
    // TODO: Cancellable, streaming writes & reads
    // TODO: Non-streaming writes & reads
    
    internal func ensureIndexes() -> EventLoopFuture<Void> {
        guard !didEnsureIndexes else {
            return eventLoop.newSucceededFuture(result: ())
        }
        
        didEnsureIndexes = true
        
        return filesCollection
            .find()
            .project(["_id": .included])
            .limit(1)
            .getFirstResult()
            .then { result in
                // Determine if the files collection is empty
                guard result == nil else {
                    return self.eventLoop.newSucceededFuture(result: ())
                }
                
                // TODO: Drivers MUST check whether the indexes already exist before attempting to create them. This supports the scenario where an application is running with read-only authorizations.
                
                return EventLoopFuture<Void>.andAll([
                    self.filesCollection.indexes.createCompound(named: "mongokitten_was_here", keys: [
                        "filename": .ascending,
                        "uploadDate": .ascending
                        ]),
                    self.chunksCollection.indexes.createCompound(named: "mongokitten_was_here", keys: [
                        "files_id": .ascending,
                        "n": .ascending
                        ], options: [.unique])
                    ], eventLoop: self.eventLoop)
        }
    }
    
}
