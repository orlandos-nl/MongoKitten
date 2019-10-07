import NIO
import MongoCore

extension MongoCollection {
    public func insert(_ document: Document) -> EventLoopFuture<InsertReply> {
        return insertMany([document])
    }
    
    public func insertManyEncoded<E: Encodable>(_ models: [E]) -> EventLoopFuture<InsertReply> {
        do {
            let documents = try models.map { model in
                return try BSONEncoder().encode(model)
            }
            
            return insertMany(documents)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
    
    public func insertEncoded<E: Encodable>(_ model: E) -> EventLoopFuture<InsertReply> {
        do {
            let document = try BSONEncoder().encode(model)
            return insert(document)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
    
    public func insertMany(_ documents: [Document]) -> EventLoopFuture<InsertReply> {
        return pool.next(for: .writable).flatMap { connection in
            let command = InsertCommand(documents: documents, inCollection: self.name)
            
            return connection.executeCodable(
                command,
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: self.sessionId ?? connection.implicitSessionId
            )
        }.decode(InsertReply.self).flatMapThrowing { reply in
            if reply.ok == 1 {
                return reply
            }
            
            throw reply
        }
    }
}
