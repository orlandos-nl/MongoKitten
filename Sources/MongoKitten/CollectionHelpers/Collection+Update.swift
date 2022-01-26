import NIO
import MongoCore
import MongoKittenCore

extension MongoCollection {
    @discardableResult
    public func updateOne(
        where query: Document,
        to document: Document
    ) async throws -> UpdateReply {
        let connection = try await pool.next(for: .writable)
        let request = UpdateCommand.UpdateRequest(where: query, to: document)
        let command = UpdateCommand(updates: [request], inCollection: self.name)
        
        return try await connection.executeCodable(
            command,
            decodeAs: UpdateReply.self,
            namespace: self.database.commandNamespace,
            in: self.transaction,
            sessionId: self.sessionId ?? connection.implicitSessionId
        )
    }

    @discardableResult
    public func updateEncoded<E: Encodable>(
        where query: Document,
        to model: E
    ) async throws -> UpdateReply {
        let document = try BSONEncoder().encode(model)
        return try await updateOne(where: query, to: document)
    }
    
    @discardableResult
    public func updateOne<Query: MongoKittenQuery>(
        where query: Query,
        to document: Document
    ) async throws -> UpdateReply {
        return try await updateOne(
            where: query.makeDocument(),
            to: document
        )
    }

    @discardableResult
    public func updateEncoded<Query: MongoKittenQuery, E: Encodable>(
        where query: Query,
        to model: E
    ) async throws -> UpdateReply {
        return try await updateEncoded(
            where: query.makeDocument(),
            to: model
        )
    }
    
    @discardableResult
    public func updateMany(
        where query: Document,
        to document: Document
    ) async throws -> UpdateReply {
        let connection = try await pool.next(for: .writable)
        var request = UpdateCommand.UpdateRequest(where: query, to: document)
        request.multi = true
        let command = UpdateCommand(updates: [request], inCollection: self.name)
        
        return try await connection.executeCodable(
            command,
            decodeAs: UpdateReply.self,
            namespace: self.database.commandNamespace,
            in: self.transaction,
            sessionId: self.sessionId ?? connection.implicitSessionId
        )
    }

    @discardableResult
    public func updateManyEncoded<E: Encodable>(
        where query: Document,
        to model: E
    ) async throws -> UpdateReply {
        let document = try BSONEncoder().encode(model)
        return try await updateMany(where: query, to: document)
    }
    
    @discardableResult
    public func updateMany<Query: MongoKittenQuery>(
        where query: Query,
        to document: Document
    ) async throws -> UpdateReply {
        return try await updateMany(
            where: query.makeDocument(),
            to: document
        )
    }

    @discardableResult
    public func updateManyEncoded<Query: MongoKittenQuery, E: Encodable>(
        where query: Query,
        to model: E
    ) async throws -> UpdateReply {
        return try await updateManyEncoded(
            where: query.makeDocument(),
            to: model
        )
    }
    
    @discardableResult
    public func updateMany(
        where query: Document,
        setting: Document?,
        unsetting: Document?
    ) async throws -> UpdateReply {
        let connection = try await pool.next(for: .writable)
        var request = UpdateCommand.UpdateRequest(where: query, setting: setting, unsetting: unsetting)
        request.multi = true
        
        let command = UpdateCommand(updates: [request], inCollection: self.name)
        
        return try await connection.executeCodable(
            command,
            decodeAs: UpdateReply.self,
            namespace: self.database.commandNamespace,
            in: self.transaction,
            sessionId: self.sessionId ?? connection.implicitSessionId
        )
    }
    
    @discardableResult
    public func upsert(_ document: Document, where query: Document) async throws -> UpdateReply {
        let connection = try await pool.next(for: .writable)
        var request = UpdateCommand.UpdateRequest(where: query, to: document)
        request.multi = false
        request.upsert = true
        
        let command = UpdateCommand(updates: [request], inCollection: self.name)
        
        return try await connection.executeCodable(
            command,
            decodeAs: UpdateReply.self,
            namespace: self.database.commandNamespace,
            in: self.transaction,
            sessionId: self.sessionId ?? connection.implicitSessionId
        )
    }

    @discardableResult
    public func upsertEncoded<E: Encodable>(_ model: E, where query: Document) async throws -> UpdateReply {
        let document = try BSONEncoder().encode(model)
        return try await upsert(document, where: query)
    }

    @discardableResult
    public func upsert<Query: MongoKittenQuery>(_ document: Document, where query: Query) async throws -> UpdateReply {
        return try await upsert(document, where: query.makeDocument())
    }

    @discardableResult
    public func upsertEncoded<Query: MongoKittenQuery, E: Encodable>(_ model: E, where query: Query) async throws -> UpdateReply {
        return try await upsertEncoded(model, where: query.makeDocument())
    }
}
