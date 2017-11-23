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
    static var writing: Bool { get }
    static var emitsCursor: Bool { get }
    
    var targetCollection: MongoCollection { get }
}

extension Command {
    public func execute(on connection: DatabaseConnection) -> Future<Void> {
        do {
            let response = try connection.execute(self, expecting: Document.self)
        
            return response.map { document in
                guard Int(lossy: document["ok"]) == 1 else {
                    throw MongoError.commandFailure(error: document)
                }
            }
        } catch {
            return Future(error: error)
        }
    }
}

extension Reply {
    struct Okay: Decodable {
        var ok: Int
    }
}

import BSON
import Async
import Bits

extension DatabaseConnection {
    func execute<E: Command, D: Decodable>(
        _ command: E,
        expecting type: D.Type
    ) throws -> Future<D> {
        return try execute(command) { reply, _ in
            guard let first = reply.documents.first else {
                throw InternalMongoError.incorrectReply(reply: reply)
            }
            
            return try BSONDecoder.decodeOrError(D.self, from: first)
        }
    }
    
    func execute<E: Command, D: Decodable, T>(
        _ command: E,
        expecting type: D.Type = D.self,
        handle result: @escaping ((D, DatabaseConnection) throws -> (T))
    ) throws -> Future<T> {
        return try execute(command) { reply, connection in
            guard let first = reply.documents.first else {
                throw InternalMongoError.incorrectReply(reply: reply)
            }
            
            return (try BSONDecoder.decodeOrError(D.self, from: first), connection)
        }.map(result)
    }
    
    func execute<E: Command, T>(
        _ command: E,
        handle result: @escaping ((ServerReply, DatabaseConnection) throws -> (T))
    ) throws -> Future<T> {
        let query = try BSONEncoder().encode(command)
        let collection = command.targetCollection.database.name + ".$cmd"
        
        let message = Message.Query(requestID: self.nextRequestId, flags: [], collection: collection, numbersToSkip: 0, numbersToReturn: 1, query: query, returnFields: nil)
        
        return try send(message: message).map { reply in
            return try result(reply, self)
        }
    }
}
