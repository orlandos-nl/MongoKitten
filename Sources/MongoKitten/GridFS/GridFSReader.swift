import Foundation
import Dispatch
import NIO

public struct GridFSReader {
    let file: GridFSFile
    
    internal init(file: GridFSFile) {
        self.file = file
    }
    
    public func readData() -> EventLoopFuture<Data> {
        return readByteBuffer().flatMapThrowing { buffer in
            return buffer.withUnsafeReadableBytes { buffer in
                return Data(bytes: buffer.baseAddress!, count: buffer.count)
            }
        }
    }
    
    public func readByteBuffer() -> EventLoopFuture<ByteBuffer> {
        var buffer = GridFSWriter.allocator.buffer(capacity: file.length)
        
        return file.fs.chunksCollection
            .find(["files_id": file._id])
            .sort(["n": .ascending])
            .decode(GridFSChunk.self)
            .forEach { chunk in
                var chunkBuffer = chunk.data.storage
                buffer.writeBuffer(&chunkBuffer)
            }.map { buffer }
    }
    
}
