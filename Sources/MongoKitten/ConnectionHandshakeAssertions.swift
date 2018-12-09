import NIO

extension Cluster {
    func withAssertions<T>(
        _ assertions: HandshakeAssertion...,
        do function: () -> EventLoopFuture<T>
    ) -> EventLoopFuture<T> {
        for assertion in assertions where !test(assertion) {
            return eventLoop.newFailedFuture(error: assertion.error)
        }
        
        return function()
    }
    
    func test(_ assertion: HandshakeAssertion) -> Bool {
        switch assertion {
        case .writable:
            if let readOnly = handshakeResult?.readOnly, readOnly { return false }
            if handshakeResult?.ismaster == false { return slaveOk }
            return true
        }
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
