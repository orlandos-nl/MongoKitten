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
    
    public init(named name: String = "fs", in database: MongoDatabase) {
        self.filesCollection = database[name + ".files"]
        self.chunksCollection = database[name + ".chunks"]
    }
    
    public func upload(_ data: Data, filename: String? = nil, id: Primitive = ObjectId(), metadata: Document? = nil, chunkSize: Int32 = GridFSBucket.defaultChunkSize) async throws -> GridFSFile {
        var buffer = GridFSFileWriter.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        
        let writer = try await GridFSFileWriter(fs: self, fileId: id, chunkSize: chunkSize, buffer: buffer)
        return try await writer.finalize(filename: filename, metadata: metadata)
    }
    
    public func upload(_ buffer: ByteBuffer, filename: String? = nil, id: Primitive = ObjectId(), metadata: Document? = nil, chunkSize: Int32 = GridFSBucket.defaultChunkSize) async throws -> GridFSFile {
        let writer = try await GridFSFileWriter(fs: self, fileId: id, chunkSize: chunkSize, buffer: buffer)
        return try await writer.finalize(filename: filename, metadata: metadata)
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
    
    public func findFile(_ query: Document) async throws -> GridFSFile? {
        var decoder = BSONDecoder()
        decoder.userInfo = [
            .gridFS: self as Any
        ]
        
        return try await filesCollection
            .find(query)
            .limit(1)
            .decode(GridFSFile.self, using: decoder)
            .firstResult()
    }
    
    public func findFile(byId id: Primitive) async throws -> GridFSFile? {
        return try await self.findFile(["_id": id])
    }
    
    public func deleteFile(byId id: Primitive) async throws {
        try await self.filesCollection.deleteAll(where: ["_id": id])
        try await self.chunksCollection.deleteAll(where: ["files_id": id])
    }
    
    internal func ensureIndexes() async throws {
        if didEnsureIndexes {
            return
        }
        
        didEnsureIndexes = true
        
        let findCollection = filesCollection
            .find()
            .project(["_id": .included])
            .limit(1)
        
        // Determine if the files collection is empty
        guard try await findCollection.firstResult() == nil else {
            return
        }
        
        // TODO: Drivers MUST check whether the indexes already exist before attempting to create them. This supports the scenario where an application is running with read-only authorizations.
        
        try await self.filesCollection.createIndex(
            named: "MongoKitten_GridFS",
            keys: [
                "filename": 1,
                "uploadDate": 1
            ]
        )
        try await self.chunksCollection.createIndex(
            named: "MongoKitten_GridFS",
            keys: [
                "files_id": 1,
                "n": 1
            ]
        )
    }
}
