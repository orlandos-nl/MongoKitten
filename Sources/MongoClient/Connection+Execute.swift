import Foundation
import Metrics
import BSON
import MongoCore
import NIO

public struct MongoServerError: Error {
    public let document: Document
}

extension MongoConnection {
    public func executeCodable<E: Encodable, D: Decodable>(
        _ command: E,
        decodeAs: D.Type,
        namespace: MongoNamespace,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier?
    ) async throws -> D {
        let reply = try await executeEncodable(command, namespace: namespace, in: transaction, sessionId: sessionId)
        let document = try reply.getDocument()
        do {
            return try BSONDecoder().decode(D.self, from: document)
        } catch {
            throw MongoServerError(document: document)
        }
    }
    
    public func executeEncodable<E: Encodable>(
        _ command: E,
        namespace: MongoNamespace,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier?
    ) async throws -> MongoServerReply {
        let request = try BSONEncoder().encode(command)
        return try await execute(request, namespace: namespace, in: transaction, sessionId: sessionId)
    }

    public func execute(
        _ command: Document,
        namespace: MongoNamespace,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) async throws -> MongoServerReply {
        let startDate = Date()
        let result = try await executeOpMessage(command, namespace: namespace, in: transaction, sessionId: sessionId)

        if let queryTimer = queryTimer {
            queryTimer.record(-startDate.timeIntervalSinceNow)
        }
        
        return result
    }
    
    public func executeOpQuery(
        _ query: inout OpQuery,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) async throws -> OpReply {
        query.header.requestId = self.nextRequestId()
        
        guard case .reply(let reply) = try await self.executeMessage(query) else {
            self.logger.error("Unexpected reply type, expected OpReply")
            throw MongoError(.queryFailure, reason: .invalidReplyType)
        }
        
        return reply
    }
    
    public func executeOpMessage(
        _ query: inout OpMessage,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) async throws -> OpMessage {
        query.header.requestId = self.nextRequestId()
        
        guard case .message(let message) = try await self.executeMessage(query) else {
            self.logger.error("Unexpected reply type, expected OpMessage")
            throw MongoError(.queryFailure, reason: .invalidReplyType)
        }
        
        return message
    }

    internal func executeOpQuery(
        _ command: Document,
        namespace: MongoNamespace,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) async throws -> MongoServerReply {
        var command = command
        
        if let id = sessionId?.id {
            command.appendValue([
                "id": id
            ] as Document, forKey: "lsid")
        }
        
        return try await executeMessage(
            OpQuery(
                query: command,
                requestId: self.nextRequestId(),
                fullCollectionName: namespace.fullCollectionName
            )
        )
    }

    internal func executeOpMessage(
        _ command: Document,
        namespace: MongoNamespace,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier? = nil
    ) async throws -> MongoServerReply {
        var command = command
        command.appendValue(namespace.databaseName, forKey: "$db")
        
        if let id = sessionId?.id {
            command.appendValue([
                "id": id
            ] as Document, forKey: "lsid")
        }
        
        // TODO: When retrying a write, don't resend transaction messages except commit & abort
        if let transaction = transaction {
            command.appendValue(transaction.number, forKey: "txnNumber")
            command.appendValue(transaction.autocommit, forKey: "autocommit")

            if await transaction.startTransaction() {
                command.appendValue(true, forKey: "startTransaction")
            }
        }
        
        return try await executeMessage(
            OpMessage(
                body: command,
                requestId: self.nextRequestId()
            )
        )
    }
}
