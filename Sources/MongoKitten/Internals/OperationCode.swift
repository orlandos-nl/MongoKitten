//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Foundation

/// All MongoDB operation codes. These are used in message headers to tell MongoDB what kind of message we're sending
internal enum OperationCode : Int32 {
    /// This is the only message that we ever receive from MongoDB. It contains the documents that we're requesting with OP_QUERY
    case Reply = 1
    /// Updates first or all results for MongoDB. Can upsert (insert if we don't have it)
    case Update = 2001
    /// Inserts one or more documents in a Mongo Collection
    case Insert = 2002
    /// When sending a message with this OPCode the message sends a request with one or two selectors and MongoDB will respond with the found results
    case Query = 2004
    /// Used on a cursor to receive more results from MongoDB
    case GetMore = 2005
    /// Used in the message that will send MongoDB a selector and delete one or all of the results
    case Delete = 2006
    /// This message kills the selected open cursor
    case KillCursors = 2007
}
