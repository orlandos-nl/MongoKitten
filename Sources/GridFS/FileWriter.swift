import Foundation
import NIO
import MongoKitten

final class FileWriter {
    
    static let allocator = ByteBufferAllocator()
    static let encoder = BSONEncoder()
    
    let fs: GridFS
    let fileId: Primitive
    let chunkSize: Int
    var buffer: ByteBuffer
    var nextChunkNumber = 0
    var length = 0
    var finalized = false
    
    internal init(fs: GridFS, fileId: Primitive, chunkSize: Int, buffer: ByteBuffer? = nil) {
        self.fs = fs
        self.fileId = fileId
        self.chunkSize = chunkSize
        self.buffer = buffer ?? FileWriter.allocator.buffer(capacity: chunkSize)
    }
    
    public func write(data: ByteBuffer) -> EventLoopFuture<Void> {
        assert(self.finalized == false, "Writing to a finalized writer is an error")
        
        self.length += data.readableBytes
        var source = data
        buffer.write(buffer: &source)
        
        guard buffer.readableBytes >= chunkSize else {
            return fs.eventLoop.newSucceededFuture(result: ())
        }
        
        return self.flush()
    }
    
    public func finalize() -> EventLoopFuture<Void> {
        assert(self.finalized == false, "Finalizing a finalized writer is an error")
        
        self.finalized = true
        
        return self.flush(finalize: true)
            .then {
                let file = File(id: self.fileId,
                                length: self.length,
                                chunkSize: self.chunkSize,
                                metadata: nil, // TODO
                                filename: nil, // TODO
                                fs: self.fs)
                
                do {
                    let encoded = try FileWriter.encoder.encode(file)
                    
                    return self.fs.filesCollection.insert(encoded).map { _ in }
                } catch {
                    return self.fs.eventLoop.newFailedFuture(error: error)
                }
        }
    }
    
    private func flush(finalize: Bool = false) -> EventLoopFuture<Void> {
        guard buffer.readableBytes > 0, finalize || buffer.readableBytes >= chunkSize else {
            return fs.eventLoop.newSucceededFuture(result: ())
        }
        
        guard let slice = buffer.readSlice(length: buffer.readableBytes >= chunkSize ? chunkSize : buffer.readableBytes) else {
            // TODO: Replace with error future
            fatalError()
        }
        
        do {
            let chunk = Chunk(filesId: fileId, sequenceNumber: nextChunkNumber, data: .init(buffer: slice))
            let encoded = try FileWriter.encoder.encode(chunk)
            
            return fs.chunksCollection.insert(encoded).map { _ in
                self.flush(finalize: finalize)
            }
        } catch {
            return fs.eventLoop.newFailedFuture(error: error)
        }
    }
    
    deinit {
        assert(finalized == true || length == 0, "A GridFS FileWriter was deinitialized, while the writing has not been finalized. This will cause orphan chunks in the chunks collection in GridFS.")
    }
    
}
