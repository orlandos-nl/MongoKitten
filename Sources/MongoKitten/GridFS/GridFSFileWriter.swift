import Foundation
import NIO

/// A GridFS file writer that can be used to upload a file to GridFS. This writer is not thread-safe.
public final class GridFSFileWriter {
    static let allocator = ByteBufferAllocator()
    static var encoder: BSONEncoder { BSONEncoder() }
    
    let fs: GridFSBucket
    let fileId: Primitive
    let chunkSize: Int32
    var buffer: ByteBuffer
    var nextChunkNumber = 0
    var length: Int
    
    private var started = false
    private var finalized = false
    
    /// Creates a new GridFSFileWriter that can be used to upload a file to GridFS.
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
    
    /// Writes a chunk to the database.
    /// Flushes the current buffer to the database if it's full enough.
    public func write(data: ByteBuffer) async throws {
        assert(!finalized, "Writing to a finalized writer is an error")
        finalized = false
        started = true
        
        self.length += data.readableBytes
        var source = data
        buffer.writeBuffer(&source)
        
        try await self.flush()
    }

    /// Removes all written chunks from the database.
    /// Finalizes the writer, meaning it cannot be used anymore
    public func cancel() async throws {
        assert(!finalized, "Finalizing a finalized writer is an error")

        self.finalized = true

        try await self.fs.chunksCollection.deleteAll(where: "files_id" == self.fileId)
    }
    
    /// Creates the file metadata in GridFS.
    /// Finalizes the writer and returns the GridFSFile that was created.
    ///
    /// - Parameters: 
    ///   - filename: The filename of the file to be created
    ///   - metadata: The metadata of the file to be created
    /// - Returns: The GridFSFile that was created
    @discardableResult
    public func finalize(filename: String? = nil, metadata: Document? = nil) async throws -> GridFSFile {
        assert(!finalized, "Finalizing a finalized writer is an error")
        
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
    
    /// Flushes the current buffer to the database if it's full enough.
    /// - Parameters:
    ///   - finalize: Whether or not to finalize the writer after flushing
    /// - Throws: An error if the chunk(s) could not be writtens
    public func flush(finalize: Bool = false) async throws {
        let chunkSize = Int(self.chunkSize) // comparison here is always to int
        
        while buffer.readableBytes > 0, finalize || buffer.readableBytes >= chunkSize {
            guard let slice = buffer.readSlice(length: buffer.readableBytes >= chunkSize ? chunkSize : buffer.readableBytes) else {
                throw MongoKittenError(.invalidGridFSChunk, reason: nil)
            }
            
            let chunk = GridFSChunk(filesId: fileId, sequenceNumber: nextChunkNumber, data: .init(buffer: slice))
            nextChunkNumber += 1
            let encoded = try GridFSFileWriter.encoder.encode(chunk)
            
            try await fs.chunksCollection.insert(encoded)
            try await self.flush(finalize: finalize)
        }
        
        // Trim the buffer to the current size
        buffer = buffer.slice()
    }
}
