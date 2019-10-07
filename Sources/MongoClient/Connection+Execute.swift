import BSON
import MongoCore
import NIO

extension MongoConnection {
    public func executeCodable<E: Encodable>(
        _ command: E,
        namespace: MongoNamespace,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier?
    ) -> EventLoopFuture<MongoServerReply> {
        do {
            let request = try BSONEncoder().encode(command)

            return execute(request, namespace: namespace)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }

    public func execute(
        _ command: Document,
        namespace: MongoNamespace,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) -> EventLoopFuture<MongoServerReply> {
        if
            let serverHandshake = serverHandshake,
            serverHandshake.maxWireVersion.supportsOpMessage
        {
            return executeOpMessage(command, namespace: namespace)
        } else {
            return executeOpQuery(command, namespace: namespace)
        }
    }
    
    public func executeOpQuery(
        _ query: inout OpQuery,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) -> EventLoopFuture<OpReply> {
        query.header.requestId = nextRequestId()
        return executeMessage(query).flatMapThrowing { reply in
            guard case .reply(let reply) = reply else {
                throw MongoError(.queryFailure, reason: .invalidReplyType)
            }
            
            return reply
        }
    }
    
    public func executeOpMessage(
        _ query: inout OpMessage,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) -> EventLoopFuture<OpMessage> {
        query.header.requestId = nextRequestId()
        return executeMessage(query).flatMapThrowing { reply in
            guard case .message(let message) = reply else {
                throw MongoError(.queryFailure, reason: .invalidReplyType)
            }
            
            return message
        }
    }

    internal func executeOpQuery(
        _ command: Document,
        namespace: MongoNamespace,
        sessionId: SessionIdentifier? = nil
    ) -> EventLoopFuture<MongoServerReply> {
        var command = command
        
        if let id = sessionId?.id {
            command["lsid"]["id"] = id
        }
        
        return executeMessage(
            OpQuery(
                query: command,
                requestId: nextRequestId(),
                fullCollectionName: namespace.fullCollectionName
            )
        )
    }

    internal func executeOpMessage(
        _ command: Document,
        namespace: MongoNamespace,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) -> EventLoopFuture<MongoServerReply> {
        var command = command
        command["$db"] = namespace.databaseName
        
        if let id = sessionId?.id {
            command["lsid"]["id"] = id
        }
        
        // TODO: When retrying a write, don't resend transaction messages except commit & abort
        if let transaction = transaction {
            command["txnNumber"] = transaction.number
            command["autocommit"] = transaction.autocommit

            if transaction.startTransaction {
                command["startTransaction"] = true
            }
        }
        return executeMessage(
            OpMessage(
                body: command,
                requestId: self.nextRequestId()
            )
        )
    }
}
