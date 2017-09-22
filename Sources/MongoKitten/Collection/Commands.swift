//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//
enum Commands {
    struct Touch: Encodable {
        var touch: String
        var data: Bool
        var index: Bool
    }
}

enum Responses {
    struct Okay: Decodable {
        var ok: Bool
    }
}

import BSON
import Schrodinger

extension Database {
    func execute<E: Encodable, D: Decodable>(_ command: E, expecting type: D.Type) throws -> Future<D> {
        let command = try BSONEncoder().encode(command)
        
        return try execute(command: command).map { reply in
            guard let first = reply.documents.first else {
                throw InternalMongoError.incorrectReply(reply: reply)
            }
            
            return try BSONDecoder().decode(D.self, from: first)
        }
    }
}
