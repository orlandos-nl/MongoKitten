import Foundation
import NIO

/// A GridFS file writer that can be used to upload a file to GridFS. This writer is not thread-safe.
///
/// `GridFSFileWriter` provides a streaming interface for uploading large files to GridFS.
/// It handles chunking the file data and managing the upload process, including error
/// handling and cleanup.
///
/// ## Basic Usage
/// ```swift
/// // Create a writer
/// let writer = try await GridFSFileWriter(
///     toBucket: gridFS,
///     fileId: ObjectId(), // Optional custom ID
///     chunkSize: 261_120  // Optional custom chunk size (default: 255KB)
/// )
///
/// // Write data in chunks
/// for chunk in dataChunks {
///     try await writer.write(data: chunk)
/// }
///
/// // Finalize and create the file
/// let file = try await writer.finalize(
///     filename: "large-file.dat",
///     metadata: [
///         "contentType": "application/octet-stream",
///         "description": "Important data"
///     ]
/// )
/// ```
///
/// ## Streaming from HTTP
/// ```swift
/// let writer = try await GridFSFileWriter(toBucket: gridFS)
///
/// do {
///     // Stream file from HTTP request
///     for try await chunk in request.body {
///         try await writer.write(data: chunk)
///     }
///
///     // Complete the upload
///     let file = try await writer.finalize(
///         filename: "uploaded-file.dat"
///     )
/// } catch {
///     // Clean up partial upload
///     try await writer.cancel()
///     throw error
/// }
/// ```
///
/// ## Error Handling
/// - If an error occurs during upload, call `cancel()` to clean up partial chunks
/// - The writer becomes invalid after calling `finalize()` or `cancel()`
/// - Writing to a finalized writer will trigger an assertion failure
///
/// ## Performance Tips
/// - The default chunk size (255KB) is suitable for most use cases
/// - Larger chunks reduce the number of database operations but use more memory
/// - The writer buffers data until it has a full chunk before writing to GridFS
/// - Call `flush()` to force writing a partial chunk to the database
///
/// ## Implementation Details
/// - Each chunk is stored as a separate document in the chunks collection
/// - Chunks are numbered sequentially starting from 0
/// - The file metadata is only written when `finalize()` is called
/// - Indexes are automatically created on the first write to a bucket
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

    /// Creates a new GridFSFileWriter and executes the given closure with it, automatically handling cleanup.
    ///
    /// This method provides a safe way to work with a GridFSFileWriter by ensuring proper cleanup,
    /// whether the operation succeeds or fails. It will:
    /// 1. Create a new writer
    /// 2. Execute your code with the writer
    /// 3. Automatically finalize the writer on success
    /// 4. Automatically cancel the writer if an error occurs
    ///
    /// Example:
    /// ```swift
    /// let file = try await GridFSFileWriter.withFileWriter(toBucket: gridFS) { writer in
    ///     try await writer.write(data: chunk1)
    ///     try await writer.write(data: chunk2)
    ///     return try await writer.finalize(filename: "example.txt")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - fs: The GridFS bucket to write to
    ///   - fileId: Optional custom ID for the file (defaults to new ObjectId)
    ///   - chunkSize: Size of chunks in bytes (defaults to 255KB)
    ///   - body: Closure that receives the writer and returns a value
    /// - Returns: The value returned by the body closure
    /// - Throws: Any error from the body closure, or from writer operations
    public static func withFileWriter<T>(
        toBucket fs: GridFSBucket,
        fileId: Primitive = ObjectId(),
        chunkSize: Int32 = GridFSBucket.defaultChunkSize,
        body: @escaping @Sendable (GridFSFileWriter) async throws -> T
    ) async throws -> T {
        let writer = try await GridFSFileWriter(toBucket: fs, fileId: fileId, chunkSize: chunkSize)
        do {
            let result = try await body(writer)
            try await writer.finalize()
            return result
        } catch {
            try await writer.cancel()
            throw error
        }
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
        buffer.discardReadBytes()
    }
}
