import Foundation
import Metrics
import BSON
import MongoCore
import NIO

public struct MongoServerError: Error {
    public let document: Document
}

extension MongoConnection {
    /// Executes a command on the server and returns the reply, or throws an error if the command failed. Uses a different protocol depending on the connection.
    /// - Parameters:
    /// - command: The command to execute on the server. Encoded as a BSON document.
    /// - decodeAs: The type to decode the reply as, used to decode the reply into a codable type.
    /// - namespace: The namespace to execute the command in. Defaults to the administrative command namespace.
    /// - transaction: The transaction to execute the command in.
    /// - sessionId: The session id to execute the command in, if any.
    /// - Returns: The reply from the server, decoded as the specified type.
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
    
    /// Executes a command on the server and returns the reply, or throws an error if the command failed. Uses a different protocol depending on the connection.
    /// - Parameters:
    ///   - command: The command to execute on the server. Encoded as a BSON document.
    ///   - namespace:  The namespace to execute the command in. Defaults to the administrative command namespace.
    ///   - transaction: The transaction to execute the command in.
    ///   - sessionId: The session id to execute the command in, if any.
    /// - Returns: The reply from the server.
    public func executeEncodable<E: Encodable>(
        _ command: E,
        namespace: MongoNamespace,
        in transaction: MongoTransaction? = nil,
        sessionId: SessionIdentifier?
    ) async throws -> MongoServerReply {
        let request = try BSONEncoder().encode(command)
        return try await execute(request, namespace: namespace, in: transaction, sessionId: sessionId)
    }

    /// Executes a command on the server and returns the reply, or throws an error if the command failed.
    /// - Parameters:
    /// s- command: The document to execute on the server.
    /// - namespace: The namespace to execute the command in. Defaults to the administrative command namespace.
    /// - transaction: The transaction to execute the command in.
    /// - sessionId: The session id to execute the command in, if any.
    /// - Returns: The reply from the server.
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
    
    /// Executes a command on the server and returns the reply, or throws an error if the command failed. This method is used for executing commands that are not encoded as BSON documents.
    /// Always uses OP_QUERY.
    /// - Parameters:
    /// - command: The command to execute on the server. Updated with the next request id.
    /// - namespace: The namespace to execute the command in. Defaults to the administrative command namespace.
    /// - transaction: The transaction to execute the command in.
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
    
    /// Executes a command on the server and returns the reply, or throws an error if the command failed. This method is used for executing commands that are not encoded as BSON documents.
    /// Always uses OP_MSG.
    /// - Parameters:
    /// - command: The command to execute on the server. Updated with the next request id.
    /// - namespace: The namespace to execute the command in. Defaults to the administrative command namespace.
    /// - transaction: The transaction to execute the command in.
    /// - Returns: The reply from the server.
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
