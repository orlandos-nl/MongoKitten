//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

protocol Command: Encodable {
    associatedtype C: Codable
    
    static var writing: Bool { get }
    static var emitsCursor: Bool { get }
    
    var targetCollection: MongoCollection<C> { get }
}

extension Command {
    public func execute(on connection: DatabaseConnection) -> Future<Void> {
        let response = connection.execute(self, expecting: Document.self)
    
        return response.map(to: Void.self) { document in
            guard Int(lossy: document["ok"]) == 1 else {
                throw MongoError.commandFailure(error: document)
            }
        }
    }
}

extension Reply {
    struct Okay: Decodable {
        var ok: Bool
    }
}

import BSON
import Async
import Bits

extension DatabaseConnection {
    func execute<E: Command, D: Decodable>(
        _ command: E,
        expecting type: D.Type
    ) -> Future<D> {
        return execute(command) { reply, _ in
            guard let first = reply.documents.first else {
                throw InternalMongoError.incorrectReply(reply: reply)
            }
            
            return try BSONDecoder.decodeOrError(D.self, from: first)
        }
    }
    
    func execute<D: Decodable>(
        query: Document,
        on database: String,
        expecting type: D.Type
    ) -> Future<D> {
        let collection = database + ".$cmd"
        
        let message = Message.Query(requestID: self.nextRequestId, flags: [], collection: collection, numbersToSkip: 0, numbersToReturn: 1, query: query, returnFields: nil)
        
        return send(message: message).map(to: D.self) { reply in
            return try BSONDecoder().decode(D.self, from: reply.documents.first ?? [:])
        }
    }
    
    func execute<E: Command, D: Decodable, T>(
        _ command: E,
        expecting type: D.Type = D.self,
        handle result: @escaping ((D, DatabaseConnection) throws -> (T))
    ) -> Future<T> {
        return execute(command) { reply, connection in
            guard let first = reply.documents.first else {
                throw InternalMongoError.incorrectReply(reply: reply)
            }
            
            return (try BSONDecoder.decodeOrError(D.self, from: first), connection)
        }.map(to: T.self, result)
    }
    
    func execute<E: Command, T>(
        _ command: E,
        handle result: @escaping ((Message.Reply, DatabaseConnection) throws -> (T))
    ) -> Future<T> {
        do {
            let query = try BSONEncoder().encode(command)
            let collection = command.targetCollection.database.name + ".$cmd"
            
            let message = Message.Query(requestID: self.nextRequestId, flags: [], collection: collection, numbersToSkip: 0, numbersToReturn: 1, query: query, returnFields: nil)
            
            return send(message: message).map(to: T.self) { reply in
                return try result(reply, self)
            }
        } catch {
            return Future<T>(error: error)
        }
    }
}
