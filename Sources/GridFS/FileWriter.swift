import Foundation
import NIO

#if !os(iOS)
import MongoKitten
#endif

final class FileWriter {
    
    static let allocator = ByteBufferAllocator()
    static let encoder = BSONEncoder()
    
    let fs: GridFSBucket
    let fileId: Primitive
    let chunkSize: Int32
    var buffer: ByteBuffer
    var nextChunkNumber = 0
    var length: Int
    var finalized = false
    
    internal init(fs: GridFSBucket, fileId: Primitive, chunkSize: Int32, buffer: ByteBuffer? = nil) {
        self.fs = fs
        self.fileId = fileId
        self.chunkSize = chunkSize
        self.buffer = buffer ?? FileWriter.allocator.buffer(capacity: Int(chunkSize))
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
    
    public func finalize(filename: String, metadata: Document? = nil) -> EventLoopFuture<Void> {
        assert(self.finalized == false, "Finalizing a finalized writer is an error")
        
        self.finalized = true
        
        return self.flush(finalize: true)
            .flatMap {
                let file = File(id: self.fileId,
                                length: self.length,
                                chunkSize: self.chunkSize,
                                metadata: metadata,
                                filename: filename,
                                fs: self.fs)
                
                do {
                    let encoded = try FileWriter.encoder.encode(file)
                    
                    return self.fs.filesCollection.insert(encoded).map { _ in }
                } catch {
                    return self.fs.eventLoop.makeFailedFuture(error)
                }
        }
    }
    
    private func flush(finalize: Bool = false) -> EventLoopFuture<Void> {
        let chunkSize = Int(self.chunkSize) // comparison here is always to int
        
        guard buffer.readableBytes > 0, finalize || buffer.readableBytes >= chunkSize else {
            return fs.eventLoop.makeSucceededFuture(())
        }
        
        guard let slice = buffer.readSlice(length: buffer.readableBytes >= chunkSize ? chunkSize : buffer.readableBytes) else {
            // TODO: Replace with error future
            fatalError()
        }
        
        do {
            let chunk = Chunk(filesId: fileId, sequenceNumber: nextChunkNumber, data: .init(buffer: slice))
            nextChunkNumber += 1
            let encoded = try FileWriter.encoder.encode(chunk)
            
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
