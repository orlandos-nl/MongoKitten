import NIO
import MongoCore

extension MongoCollection {
    public func insert(_ document: Document, writeConcern: WriteConcern? = nil) -> EventLoopFuture<InsertReply> {
        return insertMany([document], writeConcern: writeConcern)
    }
    
    public func insertManyEncoded<E: Encodable>(_ models: [E], writeConcern: WriteConcern? = nil) -> EventLoopFuture<InsertReply> {
        do {
            let documents = try models.map { model in
                return try BSONEncoder().encode(model)
            }
            
            return insertMany(documents, writeConcern: writeConcern)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
    
    public func insertEncoded<E: Encodable>(_ model: E, writeConcern: WriteConcern? = nil) -> EventLoopFuture<InsertReply> {
        do {
            let document = try BSONEncoder().encode(model)
            return insert(document, writeConcern: writeConcern)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
    
    public func insertMany(_ documents: [Document], writeConcern: WriteConcern? = nil) -> EventLoopFuture<InsertReply> {
        return pool.next(for: .writable).flatMap { connection in
            var command = InsertCommand(documents: documents, inCollection: self.name)
            command.writeConcern = writeConcern
            return connection.executeCodable(
                command,
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: self.sessionId ?? connection.implicitSessionId
            )
        }.decodeReply(InsertReply.self).flatMapThrowing { reply in
            if reply.ok == 1 {
                return reply
            }

            self.pool.logger.error("MongoDB Insert operation failed")
            throw reply
        }._mongoHop(to: hoppedEventLoop)
    }
}
