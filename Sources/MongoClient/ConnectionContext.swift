import NIO
import Foundation
import Logging
import MongoCore

internal struct MongoResponseContext {
    let requestId: Int32
    let result: EventLoopPromise<MongoServerReply>
}

/// A context for a connection to a MongoDB server. Keeps track of the server handshake and pending queries. One context is created per connection.
public final actor MongoClientContext {
    /// Pending queries
    private var queries = [MongoResponseContext]()

    /// The server handshake
    internal var serverHandshake: ServerHandshake?
    internal var lastServerHandshakeDate = Date()
    internal var didError = false
    private var outdatedDB = false
    nonisolated let logger: Logger

    internal func handleReply(_ reply: MongoServerReply) -> Bool {
        guard let index = queries.firstIndex(where: { $0.requestId == reply.responseTo }) else {
            return false
        }

        queries.remove(at: index).result.succeed(reply)
        return true
    }

    internal func setReplyCallback(forRequestId requestId: Int32, completing result: EventLoopPromise<MongoServerReply>) {
        queries.append(MongoResponseContext(requestId: requestId, result: result))
    }
    
    deinit {
        let error = MongoError(.queryFailure, reason: .connectionClosed)
        for query in queries {
            query.result.fail(error)
        }
        queries = []
    }
    
    internal func setServerHandshake(to handshake: ServerHandshake?) {
        self.serverHandshake = handshake
        self.lastServerHandshakeDate = Date()

        if let version = handshake?.maxWireVersion, version.isDeprecated, !outdatedDB {
            outdatedDB = true
            logger.warning("MongoDB server is outdated, please upgrade MongoDB")
        }
    }
    
    internal func failQuery(byRequestId requestId: Int32, error: Error) {
        guard let index = queries.firstIndex(where: { $0.requestId == requestId }) else {
            return
        }

        let query = queries[index]
        queries.remove(at: index)
        query.result.fail(error)
    }

    /// Cancels all pending queries with the given error
    public func cancelQueries(_ error: Error) {
        didError = true
        for query in queries {
            query.result.fail(error)
        }

        queries = []
    }

    public init(logger: Logger) {
        self.logger = logger
    }
}