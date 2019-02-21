import NIO

extension Cluster {
    func withAssertions<T>(
        _ assertions: HandshakeAssertion...,
        do function: () -> EventLoopFuture<T>
    ) -> EventLoopFuture<T> {
        return function()
    }
}

enum HandshakeAssertion {
    case writable
    
    var error: Error {
        switch self {
        case .writable:
            return MongoKittenError(.commandFailure, reason: .hostNotWritable)
        }
    }
}
