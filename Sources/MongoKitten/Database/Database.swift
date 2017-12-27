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
import BSON
import Dispatch
import Async

/// A Mongo Database. Cannot be publically initialized.
/// But you can get a database object by subscripting `Server` with a `String` as the database name
public final class Database {
    /// The `Server` that this Database is a part of
    public let server: Server
    
    /// The database's name
    public let name: String
    
    public var connection: DatabaseConnection
    
    public var preferences = Preferences()
    
    /// Initialise this database object
    ///
    /// - parameter database: The database to use
    /// - parameter server: The `Server` on which this database exists
    init(named name: String, atServer server: Server) {
        self.name = name
        self.server = server
        self.connection = server.connection
    }
    
    public static func connect(server settings: ClientSettings, database: String, worker: Worker) throws -> Future<Database> {
        return try DatabaseConnection.connect(host: settings.hosts.first ?? "", ssl: settings.ssl, worker: worker).map(to: Database.self) { connection in
            return Database(named: database, atServer: Server(connection: connection))
        }
    }
    
    /// Creates a GridFS collection in this database
//    public func makeGridFS(named name: String = "fs") throws -> GridFS {
//        return try GridFS(in: self, named: name)
//    }
    
    /// Get a `Collection` by providing a collection name as a `String`
    ///
    /// - parameter collection: The collection/bucket to return
    ///
    /// - returns: The requested collection in this database
    public subscript(collection: String) -> Collection {
        return Collection(named: collection, in: self)
    }
}
