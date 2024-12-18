import NIOFoundationCompat
import Foundation
import Dispatch
import NIO

/// A GridFS reader that can be used to read a file from GridFS.
///
/// `GridFSReader` provides methods for reading files stored in GridFS, either
/// as a complete file or as a stream of chunks. It supports both Foundation's
/// `Data` and NIO's `ByteBuffer` formats.
///
/// ## Basic Usage
/// ```swift
/// // Find a file
/// if let file = try await gridFS.findFile("filename" == "document.pdf") {
///     let reader = file.reader
///
///     // Read as Data
///     let data = try await reader.readData()
///     
///     // Or read as ByteBuffer
///     let buffer = try await reader.readByteBuffer()
/// }
/// ```
///
/// ## Streaming Large Files
/// For memory-efficient handling of large files, use the file's AsyncSequence implementation:
/// ```swift
/// // Stream file chunks
/// for try await chunk in file {
///     // Process each chunk (ByteBuffer)
///     await processChunk(chunk)
/// }
/// ```
///
/// ## HTTP Streaming Example
/// ```swift
/// // Stream file to HTTP response
/// let file = try await gridFS.findFile(byId: fileId)
/// let response = Response(status: .ok)
///
/// // Set content headers
/// if let filename = file.filename {
///     response.headers.contentDisposition = .attachment(filename: filename)
/// }
/// if let contentType = file.metadata?["contentType"] as? String {
///     response.headers.contentType = .init(contentType)
/// }
/// response.headers.contentLength = file.length
///
/// // Stream the file
/// for try await chunk in file {
///     try await response.write(chunk)
/// }
/// return response
/// ```
///
/// ## Performance Considerations
/// - `readData()` and `readByteBuffer()` load the entire file into memory
/// - For large files, prefer streaming using the AsyncSequence interface
/// - Chunks are read in order based on their sequence number
/// - The reader automatically handles reassembly of chunks
///
/// ## Implementation Details
/// - Chunks are read from the `{bucketName}.chunks` collection
/// - Chunks are ordered by the `n` field for proper reassembly
/// - Each chunk contains up to `chunkSize` bytes of data
/// - The last chunk may be smaller than `chunkSize`
public struct GridFSReader {
    let file: GridFSFile
    
    internal init(file: GridFSFile) {
        self.file = file
    }
    
    /// Reads the file as a contiguous Foundation Data object
    public func readData() async throws -> Data {
        var buffer = try await readByteBuffer()
        return buffer.readData(length: buffer.readableBytes)!
    }
    
    /// Reads the file as a contiguous NIO ByteBuffer object
    public func readByteBuffer() async throws -> ByteBuffer {
        var buffer = GridFSFileWriter.allocator.buffer(capacity: file.length)
        let cursor = file.fs.chunksCollection
            .find(["files_id": file._id])
            .sort(["n": .ascending])
            .decode(GridFSChunk.self)
        
        for try await chunk in cursor {
            var chunkBuffer = chunk.data.storage
            buffer.writeBuffer(&chunkBuffer)
        }
    
        return buffer
    }
}
