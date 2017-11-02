import Async
import Bits

final class PacketSerializer: Async.Stream {
    func inputStream(_ input: Message) {
        do {
            let data = try input.generateData()
            
            data.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = ByteBuffer(start: pointer, count: data.count)
                
                outputStream?(buffer)
            }
        } catch {
            errorStream?(error)
        }
    }
    
    var outputStream: OutputHandler?
    var errorStream: BaseStream.ErrorHandler?
    
    typealias Output = ByteBuffer
    
    init<DuplexStream: Async.Stream & ClosableStream>(connection: DuplexStream) where DuplexStream.Input == ByteBuffer, DuplexStream.Output == ByteBuffer {
        self.drain(into: connection)
    }
}

