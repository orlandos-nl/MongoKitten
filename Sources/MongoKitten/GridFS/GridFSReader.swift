import NIOFoundationCompat
import Foundation
import Dispatch
import NIO

public struct GridFSReader {
    let file: GridFSFile
    
    internal init(file: GridFSFile) {
        self.file = file
    }
    
    public func readData() async throws -> Data {
        var buffer = try await readByteBuffer()
        return buffer.readData(length: buffer.readableBytes)!
    }
    
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
