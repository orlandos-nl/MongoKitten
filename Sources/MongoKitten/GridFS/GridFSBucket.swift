import NIO
import Foundation


extension CodingUserInfoKey {
    static let gridFS = CodingUserInfoKey(rawValue: "GridFS")!
}

/// [See the specification](https://github.com/mongodb/specifications/blob/master/source/gridfs/gridfs-spec.rst#indexes)
public final class GridFSBucket {
    public static let defaultChunkSize: Int32 = 261_120 // 255 kB
    
    public let filesCollection: MongoCollection
    public let chunksCollection: MongoCollection
    
    private var didEnsureIndexes = false
    
    var eventLoop: EventLoop {
        return filesCollection.database.eventLoop
    }
    
    public init(named name: String = "fs", in database: MongoDatabase) {
        self.filesCollection = database[name + ".files"]
        self.chunksCollection = database[name + ".chunks"]
    }
    
    public func upload(_ data: Data, filename: String, id: Primitive = ObjectId(), metadata: Document? = nil, chunkSize: Int32 = GridFSBucket.defaultChunkSize) -> EventLoopFuture<Void> {
        var buffer = GridFSWriter.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        
        let writer = GridFSWriter(fs: self, fileId: id, chunkSize: chunkSize, buffer: buffer)
        return writer.finalize(filename: filename, metadata: metadata)
    }
    
    public func find(_ query: Document) -> MappedCursor<FindQueryBuilder, GridFSFile> {
        var decoder = BSONDecoder()
        decoder.userInfo = [
            .gridFS: self as Any
        ]
        
        return filesCollection
            .find(query)
            .decode(GridFSFile.self, using: decoder)
    }
    
    public func findFile(_ query: Document) -> EventLoopFuture<GridFSFile?> {
        var decoder = BSONDecoder()
        decoder.userInfo = [
            .gridFS: self as Any
        ]
        
        return filesCollection
            .find(query)
            .limit(1)
            .decode(GridFSFile.self, using: decoder)
            .firstResult()
    }
    
    public func findFile(byId id: Primitive) -> EventLoopFuture<GridFSFile?> {
        return self.findFile(["_id": id])
    }
    
    public func deleteFile(byId id: Primitive) -> EventLoopFuture<Void> {
        return EventLoopFuture<Void>.andAllSucceed([
            self.filesCollection.deleteAll(where: ["_id": id]).map { _ in },
            self.chunksCollection.deleteAll(where: ["files_id": id]).map { _ in }
        ], on: eventLoop)
    }
    
    // TODO: Cancellable, streaming writes & reads
    // TODO: Non-streaming writes & reads
    
    internal func ensureIndexes() -> EventLoopFuture<Void> {
        guard !didEnsureIndexes else {
            return eventLoop.makeSucceededFuture(())
        }
        
        didEnsureIndexes = true
        
        // TODO :List indexes to determine existence
        return filesCollection
            .find()
            .project(["_id": .included])
            .limit(1)
            .firstResult()
            .flatMap { result in
                // Determine if the files collection is empty
                guard result == nil else {
                    return self.eventLoop.makeSucceededFuture(())
                }
                
                // TODO: Drivers MUST check whether the indexes already exist before attempting to create them. This supports the scenario where an application is running with read-only authorizations.
                
                let createFilesIndex = self.filesCollection.createIndex(
                    named: "MongoKitten_GridFS",
                    keys: [
                        "filename": 1,
                        "uploadDate": 1
                    ]
                )
                let createChunksIndex = self.filesCollection.createIndex(
                    named: "MongoKitten_GridFS",
                    keys: [
                        "files_id": 1,
                        "n": 1
                    ]
                )
                
                return EventLoopFuture.andAllSucceed([createFilesIndex, createChunksIndex], on: self.eventLoop)
            }.flatMapErrorThrowing { error in
                self.didEnsureIndexes = false
                self.filesCollection.pool.logger.warning("Could not ensure the indexes exists for GridFS")
                throw error
            }
    }
    
}
