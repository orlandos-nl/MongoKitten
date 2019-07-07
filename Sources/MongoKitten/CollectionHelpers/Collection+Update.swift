import NIO
import MongoCore

extension MongoCollection {
    public func updateOne(where query: Document, to document: Document) -> EventLoopFuture<UpdateReply> {
        return pool.next(for: .basic).flatMap { connection in
            let request = UpdateCommand.UpdateRequest(where: query, to: document)
            let command = UpdateCommand(updates: [request], inCollection: self.name)
            
            return connection.executeCodable(command, namespace: self.database.commandNamespace)
            }.decode(UpdateReply.self)
    }
    
    public func updateMany(where query: Document, to document: Document) -> EventLoopFuture<UpdateReply> {
        return pool.next(for: .basic).flatMap { connection in
            var request = UpdateCommand.UpdateRequest(where: query, to: document)
            request.multi = true
            let command = UpdateCommand(updates: [request], inCollection: self.name)
            
            return connection.executeCodable(command, namespace: self.database.commandNamespace)
        }.decode(UpdateReply.self)
    }
    
    public func updateMany(where query: Document, setting: Document?, unsetting: Document?) -> EventLoopFuture<UpdateReply> {
        return pool.next(for: .basic).flatMap { connection in
            var request = UpdateCommand.UpdateRequest(where: query, setting: setting, unsetting: unsetting)
            request.multi = true
            
            let command = UpdateCommand(updates: [request], inCollection: self.name)
            
            return connection.executeCodable(command, namespace: self.database.commandNamespace)
        }.decode(UpdateReply.self)
    }
    
    public func upsert(_ document: Document, filter: Document) -> EventLoopFuture<UpdateReply> {
        return pool.next(for: .basic).flatMap { connection in
            var request = UpdateCommand.UpdateRequest(where: filter, to: document)
            request.multi = false
            request.upsert = true
            
            let command = UpdateCommand(updates: [request], inCollection: self.name)
            
            return connection.executeCodable(command, namespace: self.database.commandNamespace)
        }.decode(UpdateReply.self)
    }
}
