import NIO
import MongoCore
import MongoKittenCore

extension MongoCollection {
    /// Updates a single document in this collection matching the given query with the given document.
    /// - Parameter query: The query to match documents with
    /// - Parameter document: The document to update the matched document with
    /// - Returns: The reply from the server
    /// 
    /// See https://docs.mongodb.com/manual/reference/command/update/
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
            sessionId: self.sessionId ?? connection.implicitSessionId,
            logMetadata: database.logMetadata,
            traceLabel: "UpdateOne<\(namespace)>",
            baggage: baggage
        )
    }

    /// Replaces a single document in this collection matching the given query with the document encoded from the given model.
    @discardableResult
    public func updateEncoded<E: Encodable>(
        where query: Document,
        to model: E
    ) async throws -> UpdateReply {
        let document = try BSONEncoder().encode(model)
        return try await updateOne(where: query, to: document)
    }
    
    /// Replaces a single document in this collection matching the given query with the given document.
    /// - parameter query: The query to match documents with
    /// - parameter document: The document to update the matched document with
    /// - Returns: The reply from the server
    /// 
    /// See: https://docs.mongodb.com/manual/reference/command/update/
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

    /// Updates a single document in this collection matching the given query with the document encoded from the given model.
    /// - parameter query: The query to match documents with
    /// - parameter model: The model to encode and update the matched document with
    /// - Returns: The reply from the server
    /// 
    /// See: https://docs.mongodb.com/manual/reference/command/update/
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
    
    /// Update all documents matching the given query with the given document.
    /// - parameter query: The query to match documents with
    /// - parameter document: The document to update the matched documents with
    /// - Returns: The reply from the server
    /// 
    /// See: https://docs.mongodb.com/manual/reference/command/update/
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
            sessionId: self.sessionId ?? connection.implicitSessionId,
            logMetadata: database.logMetadata,
            traceLabel: "UpdateMany<\(namespace)>",
            baggage: baggage
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
    
    /// Updates all documents matching the given query with the given document.
    /// - parameter query: The query to match documents with
    /// - parameter document: The document to update the matched documents with
    /// - Returns: The reply from the server
    /// 
    /// See: https://docs.mongodb.com/manual/reference/command/update/
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

    /// Updates all documents matching the given query with the document encoded from the given model.
    /// - parameter query: The query to match documents with
    /// - parameter model: The model to encode into an update document
    /// - Returns: The reply from the server
    /// 
    /// See: https://docs.mongodb.com/manual/reference/command/update/
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
    
    /// Updates all documents matching the given query.
    /// - parameter query: The query to match documents with
    /// - parameter setting: The values to set on the matched documents
    /// - parameter unsetting: The values to unset on the matched documents
    /// - Returns: The reply from the server
    /// 
    /// See: https://docs.mongodb.com/manual/reference/command/update/
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
            sessionId: self.sessionId ?? connection.implicitSessionId,
            logMetadata: database.logMetadata,
            traceLabel: "UpdateMany<\(namespace)>",
            baggage: baggage
        )
    }
    
    /// Creates a new document in this collection if no document matches the given query. Otherwise, updates the first document matching the query.
    /// - parameter document: The document to upsert
    /// - parameter query: The query to match documents with when upserting
    /// - Returns: The reply from the server, containing the number of documents matched and the number of documents modified
    /// 
    /// See: https://docs.mongodb.com/manual/reference/command/update/
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
            sessionId: self.sessionId ?? connection.implicitSessionId,
            logMetadata: database.logMetadata,
            traceLabel: "Upsert<\(namespace)>",
            baggage: baggage
        )
    }

    /// Creates a new document in this collection if no document matches the given query. Otherwise, updates the first document matching the query.
    /// - parameter model: The model to encode and upsert
    /// - parameter query: The query to match documents with when upserting
    /// - Returns: The reply from the server, containing the number of documents matched and the number of documents modified
    /// 
    /// See: https://docs.mongodb.com/manual/reference/command/update/
    @discardableResult
    public func upsertEncoded<E: Encodable>(_ model: E, where query: Document) async throws -> UpdateReply {
        let document = try BSONEncoder().encode(model)
        return try await upsert(document, where: query)
    }

    /// Creates a new document in this collection if no document matches the given query. Otherwise, updates the first document matching the query.
    /// - parameter model: The model to encode and upsert
    /// - parameter query: The query to match documents with when upserting
    /// - Returns: The reply from the server, containing the number of documents matched and the number of documents modified
    /// 
    /// See: https://docs.mongodb.com/manual/reference/command/update/
    @discardableResult
    public func upsert<Query: MongoKittenQuery>(_ document: Document, where query: Query) async throws -> UpdateReply {
        return try await upsert(document, where: query.makeDocument())
    }

    /// Creates a new document in this collection if no document matches the given query. Otherwise, updates the first document matching the query.
    /// - parameter model: The model to encode and upsert
    /// - parameter query: The query to match documents with when upserting
    /// - Returns: The reply from the server, containing the number of documents matched and the number of documents modified
    /// 
    /// See: https://docs.mongodb.com/manual/reference/command/update/
    @discardableResult
    public func upsertEncoded<Query: MongoKittenQuery, E: Encodable>(_ model: E, where query: Query) async throws -> UpdateReply {
        return try await upsertEncoded(model, where: query.makeDocument())
    }
}
