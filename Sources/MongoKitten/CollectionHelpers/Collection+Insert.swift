import NIO
import MongoCore

extension MongoCollection {
    /// Creates a new document in this collection with the given document.
    @discardableResult
    public func insert(_ document: Document, writeConcern: WriteConcern? = nil) async throws -> InsertReply {
        return try await insertMany([document], writeConcern: writeConcern)
    }
    
    /// Creates new documents in this collection with the given documents.
    @discardableResult
    public func insertManyEncoded<E: Encodable>(_ models: [E], writeConcern: WriteConcern? = nil) async throws -> InsertReply {
        let documents = try models.map { model in
            return try BSONEncoder().encode(model)
        }
        
        return try await insertMany(documents, writeConcern: writeConcern)
    }
    
    @discardableResult
    public func insertEncoded<E: Encodable>(_ model: E, writeConcern: WriteConcern? = nil) async throws -> InsertReply {
        let document = try BSONEncoder().encode(model)
        return try await insert(document, writeConcern: writeConcern)
    }
    
    /// Creates new documents in this collection with the given documents.
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
            sessionId: self.sessionId ?? connection.implicitSessionId
        )
        
        if reply.ok == 1 {
            return reply
        }

        self.pool.logger.error("MongoDB Insert operation failed")
        throw reply
    }
}
