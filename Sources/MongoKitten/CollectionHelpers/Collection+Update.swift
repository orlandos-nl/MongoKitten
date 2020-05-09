import NIO
import MongoCore

extension MongoCollection {
    public func updateOne(
        where query: Document,
        to document: Document
    ) -> EventLoopFuture<UpdateReply> {
        return pool.next(for: .basic).flatMap { connection in
            let request = UpdateCommand.UpdateRequest(where: query, to: document)
            let command = UpdateCommand(updates: [request], inCollection: self.name)
            
            return connection.executeCodable(
                command,
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: self.sessionId ?? connection.implicitSessionId
            )
        }.decodeReply(UpdateReply.self)._mongoHop(to: hoppedEventLoop)
    }

    public func updateOne<E: Encodable>(
        where query: Document,
        to model: E
    ) -> EventLoopFuture<UpdateReply> {
        do {
            let document = try BSONEncoder().encode(model)
            return updateOne(where: query, to: document)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
    
    public func updateOne<Query: MongoKittenQuery>(
        where query: Query,
        to document: Document
    ) -> EventLoopFuture<UpdateReply> {
        return updateOne(
            where: query.makeDocument(),
            to: document
        )
    }

    public func updateOne<Query: MongoKittenQuery, E: Encodable>(
        where query: Query,
        to model: E
    ) -> EventLoopFuture<UpdateReply> {
        return updateOne(
            where: query.makeDocument(),
            to: model
        )
    }
    
    public func updateMany(
        where query: Document,
        to document: Document
    ) -> EventLoopFuture<UpdateReply> {
        return pool.next(for: .basic).flatMap { connection in
            var request = UpdateCommand.UpdateRequest(where: query, to: document)
            request.multi = true
            let command = UpdateCommand(updates: [request], inCollection: self.name)
            
            return connection.executeCodable(
                command,
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: self.sessionId ?? connection.implicitSessionId
            )
        }.decodeReply(UpdateReply.self)._mongoHop(to: hoppedEventLoop)
    }

    public func updateMany<E: Encodable>(
        where query: Document,
        to model: E
    ) -> EventLoopFuture<UpdateReply> {
        do {
            let document = try BSONEncoder().encode(model)
            return updateMany(where: query, to: document)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
    
    public func updateMany<Query: MongoKittenQuery>(
        where query: Query,
        to document: Document
    ) -> EventLoopFuture<UpdateReply> {
        return updateMany(
            where: query.makeDocument(),
            to: document
        )
    }

    public func updateMany<Query: MongoKittenQuery, E: Encodable>(
        where query: Query,
        to model: E
    ) -> EventLoopFuture<UpdateReply> {
        return updateMany(
            where: query.makeDocument(),
            to: model
        )
    }
    
    public func updateMany(
        where query: Document,
        setting: Document?,
        unsetting: Document?
    ) -> EventLoopFuture<UpdateReply> {
        return pool.next(for: .basic).flatMap { connection in
            var request = UpdateCommand.UpdateRequest(where: query, setting: setting, unsetting: unsetting)
            request.multi = true
            
            let command = UpdateCommand(updates: [request], inCollection: self.name)
            
            return connection.executeCodable(
                command,
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: self.sessionId ?? connection.implicitSessionId
            )
        }.decodeReply(UpdateReply.self)._mongoHop(to: hoppedEventLoop)
    }
    
    public func upsert(_ document: Document, where query: Document) -> EventLoopFuture<UpdateReply> {
        return pool.next(for: .basic).flatMap { connection in
            var request = UpdateCommand.UpdateRequest(where: query, to: document)
            request.multi = false
            request.upsert = true
            
            let command = UpdateCommand(updates: [request], inCollection: self.name)
            
            return connection.executeCodable(
                command,
                namespace: self.database.commandNamespace,
                in: self.transaction,
                sessionId: self.sessionId ?? connection.implicitSessionId
            )
        }.decodeReply(UpdateReply.self)._mongoHop(to: hoppedEventLoop)
    }

    public func upsert<E: Encodable>(_ model: E, where query: Document) -> EventLoopFuture<UpdateReply> {
        do {
            let document = try BSONEncoder().encode(model)
            return upsert(document, where: query)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }

    public func upsert<Query: MongoKittenQuery>(_ document: Document, where query: Query) -> EventLoopFuture<UpdateReply> {
        return upsert(document, where: query.makeDocument())
    }

    public func upsert<Query: MongoKittenQuery, E: Encodable>(_ model: E, where query: Query) -> EventLoopFuture<UpdateReply> {
        return upsert(model, where: query.makeDocument())
    }

}
