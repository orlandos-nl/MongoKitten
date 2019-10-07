import NIO
import MongoCore

internal struct MongoResponseContext {
    let requestId: Int32
    let result: EventLoopPromise<MongoServerReply>
}

public final class MongoClientContext {
    private var queries = [MongoResponseContext]()
    internal var serverHandshake: ServerHandshake?
    internal var didError = false

    public func handleReply(_ reply: MongoServerReply) -> Bool {
        guard let index = queries.firstIndex(where: { $0.requestId == reply.responseTo }) else {
            return false
        }

        let query = queries[index]
        queries.remove(at: index)
        query.result.succeed(reply)
        return true
    }

    public func awaitReply(toRequestId requestId: Int32, completing result: EventLoopPromise<MongoServerReply>) {
        queries.append(MongoResponseContext(requestId: requestId, result: result))
    }
    
    deinit {
        self.cancelQueries(MongoError(.queryFailure, reason: .connectionClosed))
    }

    public func cancelQueries(_ error: Error) {
        for query in queries {
            query.result.fail(error)
        }

        queries = []
    }

    public init() {}
}

struct MongoClientRequest<Request: MongoRequestMessage> {
    let command: Request
    let namespace: MongoNamespace
    
    init(command: Request, namespace: MongoNamespace) {
        self.command = command
        self.namespace = namespace
    }
}
