import NIO
import MongoClient
import MongoCore

extension MongoCollection {
    /// Creates a new document in this collection with the given document. The document must have an `_id` field, or one will be generated.
    /// - parameter document: The document to insert
    /// - parameter writeConcern: The write concern to use for this operation
    /// - returns: The reply from the server
    /// 
    /// See also: [Insert Command](https://docs.mongodb.com/manual/reference/command/insert/)
    @discardableResult
    public func insert(_ document: Document, writeConcern: WriteConcern? = nil) async throws -> InsertReply {
        return try await insertMany([document], writeConcern: writeConcern)
    }
    
    /// Creates new documents in this collection with the given models encoded to BSON Documents.
    /// - parameter models: The models to insert
    /// - parameter writeConcern: The write concern to use for this operation
    /// - returns: The reply from the server
    /// 
    /// See also: [Insert Command](https://docs.mongodb.com/manual/reference/command/insert/)
    @discardableResult
    public func insertManyEncoded<E: Encodable>(_ models: [E], writeConcern: WriteConcern? = nil) async throws -> InsertReply {
        let documents = try models.map { model in
            return try BSONEncoder().encode(model)
        }
        
        return try await insertMany(documents, writeConcern: writeConcern)
    }
    
    /// Creates a new document in this collection with the given model encoded to a BSON Document.
    /// - parameter model: The model to insert
    /// - parameter writeConcern: The write concern to use for this operation
    /// 
    /// See also: [Insert Command](https://docs.mongodb.com/manual/reference/command/insert/)
    @discardableResult
    public func insertEncoded<E: Encodable>(_ model: E, writeConcern: WriteConcern? = nil) async throws -> InsertReply {
        let document = try BSONEncoder().encode(model)
        return try await insert(document, writeConcern: writeConcern)
    }
    
    /// Creates new documents in this collection with the given documents.
    /// - parameter documents: The documents to insert
    /// - parameter writeConcern: The write concern to use for this operation
    /// - returns: The reply from the server
    /// 
    /// See also: [Insert Command](https://docs.mongodb.com/manual/reference/command/insert/)
    @discardableResult
    public func insertMany(_ documents: [Document], writeConcern: WriteConcern? = nil) async throws -> InsertReply {
        let connection = try await pool.next(for: .writable)
        var command = InsertCommand(documents: documents, inCollection: self.name)
        command.writeConcern = writeConcern
        let reply = try await connection.executeCodable(
            command,
            decodeAs: InsertReply.self,
            namespace: self.database.commandNamespace,
            in: self.transaction,
            sessionId: self.sessionId ?? connection.implicitSessionId,
            logMetadata: database.logMetadata,
            traceLabel: "Insert<\(namespace)>",
            serviceContext: context
        )
        
        if reply.ok == 1 {
            return reply
        }

        self.pool.logger.trace("MongoDB Insert operation failed with \(reply.writeErrors?.count ?? 0) write errors", metadata: database.logMetadata)
        throw reply
    }
}
