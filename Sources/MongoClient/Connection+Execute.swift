import Foundation
import Metrics
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

            return execute(request, namespace: namespace, in: transaction, sessionId: sessionId)
        } catch {
            self.logger.error("Unable to encode MongoDB request")
            return eventLoop.makeFailedFuture(error)
        }
    }

    public func execute(
        _ command: Document,
        namespace: MongoNamespace,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) -> EventLoopFuture<MongoServerReply> {
        let result: EventLoopFuture<MongoServerReply>
        
        if
            let serverHandshake = serverHandshake,
            serverHandshake.maxWireVersion.supportsOpMessage
        {
            result = executeOpMessage(command, namespace: namespace, in: transaction, sessionId: sessionId)
        } else {
            result = executeOpQuery(command, namespace: namespace, in: transaction, sessionId: sessionId)
        }

        if let queryTimer = queryTimer {
            let date = Date()
            result.whenComplete { _ in
                queryTimer.record(-date.timeIntervalSinceNow)
            }
        }
        
        return result
    }
    
    public func executeOpQuery(
        _ query: inout OpQuery,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) -> EventLoopFuture<OpReply> {
        return self.eventLoop.flatSubmit {
            query.header.requestId = nextRequestId()
            return executeMessage(query).flatMapThrowing { reply in
                guard case .reply(let reply) = reply else {
                    self.logger.error("Unexpected reply type, expected OpReply")
                    throw MongoError(.queryFailure, reason: .invalidReplyType)
                }
                
                return reply
            }
        }
    }
    
    public func executeOpMessage(
        _ query: inout OpMessage,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) -> EventLoopFuture<OpMessage> {
        return self.eventLoop.flatSubmit {
            query.header.requestId = nextRequestId()
            return executeMessage(query).flatMapThrowing { reply in
                guard case .message(let message) = reply else {
                    self.logger.error("Unexpected reply type, expected OpMessage")
                    throw MongoError(.queryFailure, reason: .invalidReplyType)
                }
                
                return message
            }
        }
    }

    internal func executeOpQuery(
        _ command: Document,
        namespace: MongoNamespace,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) -> EventLoopFuture<MongoServerReply> {
        return self.eventLoop.flatSubmit {
            var command = command
            
            if let id = sessionId?.id {
                // TODO: This is memory heavy
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
    }

    internal func executeOpMessage(
        _ command: Document,
        namespace: MongoNamespace,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) -> EventLoopFuture<MongoServerReply> {
        return self.eventLoop.flatSubmit {
            var command = command
            command["$db"] = namespace.databaseName
            
            if let id = sessionId?.id {
                // TODO: This is memory heavy
                command["lsid"]["id"] = id
            }
            
            // TODO: When retrying a write, don't resend transaction messages except commit & abort
            if let transaction = transaction {
                command["txnNumber"] = transaction.number
                command["autocommit"] = transaction.autocommit

                if transaction.startTransaction() {
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
}
