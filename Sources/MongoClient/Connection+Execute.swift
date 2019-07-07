import BSON
import MongoCore
import NIO

extension MongoConnection {
    public func executeCodable<E: Encodable>(_ command: E, namespace: MongoNamespace) -> EventLoopFuture<MongoServerReply> {
        do {
            let request = try BSONEncoder().encode(command)

            return execute(request, namespace: namespace)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }

    public func execute(_ command: Document, namespace: MongoNamespace) -> EventLoopFuture<MongoServerReply> {
        if
            let serverHandshake = serverHandshake,
            serverHandshake.maxWireVersion.supportsOpMessage
        {
            return executeOpMessage(command, namespace: namespace)
        } else {
            return executeOpQuery(command, namespace: namespace)
        }
    }
    
    public func executeOpQuery(_ query: inout OpQuery) -> EventLoopFuture<OpReply> {
        query.header.requestId = nextRequestId()
        return executeMessage(query).flatMapThrowing { reply in
            guard case .reply(let reply) = reply else {
                throw MongoError(.queryFailure, reason: .invalidReplyType)
            }
            
            return reply
        }
    }
    
    public func executeOpMessage(_ query: inout OpMessage) -> EventLoopFuture<OpMessage> {
        query.header.requestId = nextRequestId()
        return executeMessage(query).flatMapThrowing { reply in
            guard case .message(let message) = reply else {
                throw MongoError(.queryFailure, reason: .invalidReplyType)
            }
            
            return message
        }
    }

    internal func executeOpQuery(_ command: Document, namespace: MongoNamespace) -> EventLoopFuture<MongoServerReply> {
        // TODO: Sessions + Transactions
//        document["lsid"]["id"] = session.sessionId.id
        return executeMessage(OpQuery(query: command, requestId: nextRequestId(), fullCollectionName: namespace.fullCollectionName))
    }

    internal func executeOpMessage(_ command: Document, namespace: MongoNamespace) -> EventLoopFuture<MongoServerReply> {
        var command = command
        command["$db"] = namespace.databaseName
        // TODO: Sessions + transactions
//        if includeSession, let session = data.session {
//            document["lsid"]["id"] = session.sessionId.id
//        }
//
//        if let transaction = data.transaction {
//            document["txnNumber"] = transaction.id
//            document["autocommit"] = transaction.autocommit
//
//            if transaction.startTransaction {
//                document["startTransaction"] = true
//            }
//        }
        return executeMessage(OpMessage(body: command, requestId: self.nextRequestId()))
    }
}
