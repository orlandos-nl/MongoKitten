import Async
import Bits

final class PacketSerializer: Async.Stream {
    typealias Output = ByteBuffer
    
    let stream = BasicStream<Output>()
    
    func onInput(_ input: Message) {
        do {
            let data = try input.generateData()
            
            data.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = ByteBuffer(start: pointer, count: data.count)
                
                stream.onInput(buffer)
            }
        } catch {
            stream.onError(error)
        }
    }
    
    func onError(_ error: Error) {
        stream.onError(error)
    }
    
    func onOutput<I>(_ input: I) where I : InputStream, PacketSerializer.Output == I.Input {
        stream.onOutput(input)
    }
    
    func close() {
        stream.close()
    }
    
    func onClose(_ onClose: ClosableStream) {
        stream.onClose(onClose)
    }
    
    init() {}
}

