import Foundation
import NIO

public final class GridFSFileWriter {
    static let allocator = ByteBufferAllocator()
    static let encoder = BSONEncoder()
    
    let fs: GridFSBucket
    let fileId: Primitive
    let chunkSize: Int32
    var buffer: ByteBuffer
    var nextChunkNumber = 0
    var length: Int
    var finalized = false
    
    public init(toBucket fs: GridFSBucket, fileId: Primitive = ObjectId(), chunkSize: Int32 = GridFSBucket.defaultChunkSize) async throws {
        self.fs = fs
        self.fileId = fileId
        self.chunkSize = chunkSize
        self.buffer = GridFSFileWriter.allocator.buffer(capacity: Int(chunkSize))
        self.length = self.buffer.readableBytes
        
        try await fs.ensureIndexes()
    }
    
    internal init(fs: GridFSBucket, fileId: Primitive = ObjectId(), chunkSize: Int32 = GridFSBucket.defaultChunkSize, buffer: ByteBuffer? = nil) async throws {
        self.fs = fs
        self.fileId = fileId
        self.chunkSize = chunkSize
        self.buffer = buffer ?? GridFSFileWriter.allocator.buffer(capacity: Int(chunkSize))
        self.length = self.buffer.readableBytes
        
        try await fs.ensureIndexes()
    }
    
    public func write(data: ByteBuffer) async throws {
        assert(self.finalized == false, "Writing to a finalized writer is an error")
        
        self.length += data.readableBytes
        var source = data
        buffer.writeBuffer(&source)
        
        guard buffer.readableBytes >= chunkSize else {
            return
        }
        
        try await self.flush()
    }
    
    public func finalize(filename: String? = nil, metadata: Document? = nil) async throws -> GridFSFile {
        assert(self.finalized == false, "Finalizing a finalized writer is an error")
        
        self.finalized = true
        
        try await self.flush(finalize: true)
        let file = GridFSFile(
            id: self.fileId,
            length: self.length,
            chunkSize: self.chunkSize,
            metadata: metadata,
            filename: filename,
            fs: self.fs
        )
        
        let encoded = try GridFSFileWriter.encoder.encode(file)
        
        try await self.fs.filesCollection.insert(encoded)
        return file
    }
    
    public func flush(finalize: Bool = false) async throws {
        let chunkSize = Int(self.chunkSize) // comparison here is always to int
        
        guard buffer.readableBytes > 0, finalize || buffer.readableBytes >= chunkSize else {
            return
        }
        
        guard let slice = buffer.readSlice(length: buffer.readableBytes >= chunkSize ? chunkSize : buffer.readableBytes) else {
            throw MongoKittenError(.invalidGridFSChunk, reason: nil)
        }
        
        let chunk = GridFSChunk(filesId: fileId, sequenceNumber: nextChunkNumber, data: .init(buffer: slice))
        nextChunkNumber += 1
        let encoded = try GridFSFileWriter.encoder.encode(chunk)
        
        try await fs.chunksCollection.insert(encoded)
        try await self.flush(finalize: finalize)
    }
    
    deinit {
        assert(finalized == true || length == 0, "A GridFS FileWriter was deinitialized, while the writing has not been finalized. This will cause orphan chunks in the chunks collection in GridFS.")
    }
}
