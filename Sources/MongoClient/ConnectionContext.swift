import NIO
import NIOConcurrencyHelpers
import Logging
import MongoCore

internal struct MongoResponseContext {
    let requestId: Int32
    let result: EventLoopPromise<MongoServerReply>
}

public final class MongoClientContext {
    private let queriesLock = Lock()
    private var queries = [MongoResponseContext]()
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
        if let query: MongoResponseContext = queriesLock.withLock({
            guard let index = queries.firstIndex(where: { $0.requestId == reply.responseTo }) else {
                return nil
            }

            let query = queries[index]
            queries.remove(at: index)
            return query
        }) {
            query.result.succeed(reply)
            return true
        } else {
            return false
        }
    }

    internal func awaitReply(toRequestId requestId: Int32, completing result: EventLoopPromise<MongoServerReply>) {
        queriesLock.withLock {
            queries.append(MongoResponseContext(requestId: requestId, result: result))
        }
    }
    
    deinit {
        self.cancelQueries(MongoError(.queryFailure, reason: .connectionClosed))
    }
    
    public func failQuery(byRequestId requestId: Int32, error: Error) {
        if let query: MongoResponseContext = queriesLock.withLock({
            guard let index = queries.firstIndex(where: { $0.requestId == requestId }) else {
                return nil
            }

            let query = queries[index]
            queries.remove(at: index)
            return query
        }) {
            query.result.fail(error)
        }
    }

    public func cancelQueries(_ error: Error) {
        let stolenQueries: [MongoResponseContext] = queriesLock.withLock {
            let stolenQueries = queries
            queries.removeAll()
            return stolenQueries
        }
    
        for query in stolenQueries {
            query.result.fail(error)
        }
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
