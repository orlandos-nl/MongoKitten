import Foundation
import Async
import Bits

final class PacketSerializer: Async.Stream, ConnectionContext {
    typealias Input = Message
    typealias Output = ByteBuffer
    
    /// Upstream output stream outputting Messages
    private var upstream: ConnectionContext?
    
    /// Downstream client and eventloop input stream
    private var downstream: AnyInputStream<Output>?
    
    /// The amount of requested output remaining
    private var requestedOutputRemaining: UInt = 0
    
    var backlog = [Message]()
    var backlogProcessed = 0
    var sending: Data?
    
    func output<S>(to inputStream: S) where S : Async.InputStream, PacketSerializer.Output == S.Input {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }
    
    func connection(_ event: ConnectionEvent) {
        switch event {
        case .request(let amount):
            requestedOutputRemaining += amount
            flushBacklog()
        case .cancel:
            requestedOutputRemaining = 0
        }
    }
    
    func input(_ event: InputEvent<Message>) {
        switch event {
        case .close:
            self.cancel()
        case .connect(let upstream):
            self.upstream = upstream
        case .error(let error):
            downstream?.error(error)
        case .next(let input):
            flushBacklog(and: input)
        }
    }
    
    func flushBacklog(and input: Input? = nil) {
        do {
            defer {
                backlog.removeFirst(backlogProcessed)
                self.backlogProcessed = 0
            }
            
            while backlog.count > backlogProcessed, requestedOutputRemaining > 0 {
                let entity = try backlog[backlogProcessed].generateData()
                backlogProcessed += 1
                requestedOutputRemaining -= 1
                
                flush(entity)
            }
            
            if let input = input {
                if requestedOutputRemaining > 0 {
                    let entity = try input.generateData()
                    requestedOutputRemaining -= 1
                    
                    flush(entity)
                } else {
                    backlog.append(input)
                }
            }
        } catch {
            self.downstream?.error(error)
        }
    }
    
    func flush(_ input: Data) {
        self.sending = input
        
        input.withByteBuffer { buffer in
            self.downstream?.next(buffer)
        }
    }
    
    init() {}
}

