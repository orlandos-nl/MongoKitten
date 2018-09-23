import BSON
import NIO
import Foundation

struct SessionIdentifier: Codable {
    var id: Binary
    
    init(allocator: ByteBufferAllocator) {
        let uuid = UUID().uuid
        
        var buffer = allocator.buffer(capacity: 16)
        buffer.write(integer: uuid.0)
        buffer.write(integer: uuid.1)
        buffer.write(integer: uuid.2)
        buffer.write(integer: uuid.3)
        buffer.write(integer: uuid.4)
        buffer.write(integer: uuid.5)
        buffer.write(integer: uuid.6)
        buffer.write(integer: uuid.7)
        buffer.write(integer: uuid.8)
        buffer.write(integer: uuid.9)
        buffer.write(integer: uuid.10)
        buffer.write(integer: uuid.11)
        buffer.write(integer: uuid.12)
        buffer.write(integer: uuid.13)
        buffer.write(integer: uuid.14)
        buffer.write(integer: uuid.15)
        
        self.id = Binary(subType: .uuid, buffer: buffer)
    }
}

public final class ClientSession {
    let connection: Connection
    let clusterTime: Document?
    let options: SessionOptions
    let sessionId: SessionIdentifier
    
    init() {
        fatalError()
    }
    
    func advanceClusterTime(to time: Document) {
        // Increase if the new time is in the future
        // Ignore if the new time <= the current time
    }
    
    public func end() -> EventLoopFuture<Void> {
        let command = EndSessionsCommand(
            [sessionId],
            inNamespace: connection["admin"]["$cmd"].namespace
        )
        
        return command.execute(on: connection)
    }
    
    deinit {
        _ = end()
    }
}

internal final class ServerSession {
    let sessionId: SessionIdentifier
    let lastUse: Date
    
    init(for sessionId: SessionIdentifier) {
        self.sessionId = sessionId
        self.lastUse = Date()
    }
}

//final class Transaction {
//    let session: ClientSession
//
//    deinit {
//
//    }
//}
//
struct SessionOptions {

}

extension Connection {

}
