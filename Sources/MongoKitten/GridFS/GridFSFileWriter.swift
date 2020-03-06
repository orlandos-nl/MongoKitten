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
    
    public init(toBucket fs: GridFSBucket, fileId: Primitive, chunkSize: Int32) {
        self.fs = fs
        self.fileId = fileId
        self.chunkSize = chunkSize
        self.buffer = GridFSFileWriter.allocator.buffer(capacity: Int(chunkSize))
        self.length = self.buffer.readableBytes
    }
    
    internal init(fs: GridFSBucket, fileId: Primitive, chunkSize: Int32, buffer: ByteBuffer? = nil) {
        self.fs = fs
        self.fileId = fileId
        self.chunkSize = chunkSize
        self.buffer = buffer ?? GridFSFileWriter.allocator.buffer(capacity: Int(chunkSize))
        self.length = self.buffer.readableBytes
    }
    
    public func write(data: ByteBuffer) -> EventLoopFuture<Void> {
        assert(self.finalized == false, "Writing to a finalized writer is an error")
        
        self.length += data.readableBytes
        var source = data
        buffer.writeBuffer(&source)
        
        guard buffer.readableBytes >= chunkSize else {
            return fs.eventLoop.makeSucceededFuture(())
        }
        
        return self.flush()
    }
    
    public func finalize(filename: String, metadata: Document? = nil) -> EventLoopFuture<GridFSFile> {
        assert(self.finalized == false, "Finalizing a finalized writer is an error")
        
        self.finalized = true
        
        return self.flush(finalize: true).flatMap {
            let file = GridFSFile(
                id: self.fileId,
                length: self.length,
                chunkSize: self.chunkSize,
                metadata: metadata,
                filename: filename,
                fs: self.fs
            )
            
            do {
                let encoded = try GridFSFileWriter.encoder.encode(file)
                
                return self.fs.filesCollection.insert(encoded).map { _ in
                    return file
                }
            } catch {
                return self.fs.eventLoop.makeFailedFuture(error)
            }
        }
    }
    
    public func flush(finalize: Bool = false) -> EventLoopFuture<Void> {
        let chunkSize = Int(self.chunkSize) // comparison here is always to int
        
        guard buffer.readableBytes > 0, finalize || buffer.readableBytes >= chunkSize else {
            return fs.eventLoop.makeSucceededFuture(())
        }
        
        guard let slice = buffer.readSlice(length: buffer.readableBytes >= chunkSize ? chunkSize : buffer.readableBytes) else {
            // TODO: Replace with error future
            fatalError()
        }
        
        do {
            let chunk = GridFSChunk(filesId: fileId, sequenceNumber: nextChunkNumber, data: .init(buffer: slice))
            nextChunkNumber += 1
            let encoded = try GridFSFileWriter.encoder.encode(chunk)
            
            return fs.chunksCollection.insert(encoded).flatMap { _ in
                return self.flush(finalize: finalize)
            }
        } catch {
            return fs.eventLoop.makeFailedFuture(error)
        }
    }
    
    deinit {
        assert(finalized == true || length == 0, "A GridFS FileWriter was deinitialized, while the writing has not been finalized. This will cause orphan chunks in the chunks collection in GridFS.")
    }
}
