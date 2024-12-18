import NIO
import Logging
import MongoCore

internal struct MongoResponseContext {
    let requestId: Int32
    let result: EventLoopPromise<MongoServerReply>
}

public final class MongoClientContext {
    private var queries = [Int32: MongoResponseContext]()
    internal var serverHandshake: ServerHandshake? {
        didSet {
            if let version = serverHandshake?.maxWireVersion, version.isDeprecated {
                logger.warning("MongoDB server is outdated, please upgrade MongoDB")
            }
        }
    }
    internal var didError = false
    let logger: Logger

    internal func handleReply(_ reply: MongoServerReply) -> Bool {
        guard let query = queries.removeValue(forKey: reply.responseTo) else {
            return false
        }

        query.result.succeed(reply)
        return true
    }

    internal func awaitReply(toRequestId requestId: Int32, completing result: EventLoopPromise<MongoServerReply>) {
        queries[requestId] = MongoResponseContext(requestId: requestId, result: result)
    }
    
    deinit {
        self.cancelQueries(MongoError(.queryFailure, reason: .connectionClosed))
    }
    
    public func failQuery(byRequestId requestId: Int32, error: Error) {
        guard let query = queries.removeValue(forKey: requestId) else {
            return
        }
        
        query.result.fail(error)
    }

    public func cancelQueries(_ error: Error) {
        for query in queries.values {
            query.result.fail(error)
        }

        queries = [:]
    }

    public init(logger: Logger) {
        self.logger = logger
    }
}

struct MongoClientRequest<Request: MongoRequestMessage> {
    let command: Request
    let namespace: MongoNamespace
    
    init(command: Request, namespace: MongoNamespace) {
        self.command = command
        self.namespace = namespace
    }
}
