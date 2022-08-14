import NIO
import Logging
import MongoCore

internal struct MongoResponseContext {
    let requestId: Int32
    let result: EventLoopPromise<MongoServerReply>
}

public final actor MongoClientContext {
    private var queries = [MongoResponseContext]()
    internal var serverHandshake: ServerHandshake?
    internal var didError = false
    private var outdatedDB = false
    let logger: Logger

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

struct MongoClientRequest<Request: MongoRequestMessage> {
    let command: Request
    let namespace: MongoNamespace
    
    init(command: Request, namespace: MongoNamespace) {
        self.command = command
        self.namespace = namespace
    }
}
