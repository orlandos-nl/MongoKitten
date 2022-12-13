import NIOFoundationCompat
import Foundation
import Dispatch
import NIO

/// A GridFS reader that can be used to read a file from GridFS.
public struct GridFSReader {
    let file: GridFSFile
    
    internal init(file: GridFSFile) {
        self.file = file
    }
    
    /// Reads the file as a Foundation Data object
    public func readData() async throws -> Data {
        var buffer = try await readByteBuffer()
        return buffer.readData(length: buffer.readableBytes)!
    }
    
    /// Reads the file as a NIO ByteBuffer object
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
