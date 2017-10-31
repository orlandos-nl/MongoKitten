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
    
    public let connectionPool: ConnectionPool
    
    public var preferences = Preferences()
    
    /// A cache of all collections in this Database.
    ///
    /// Mainly used for keeping track of event listeners
    private var collections = [String: Weak<Collection>]()
    
    /// Initialise this database object
    ///
    /// - parameter database: The database to use
    /// - parameter server: The `Server` on which this database exists
    public init(named name: String, atServer server: Server, connectionPool: ConnectionPool) {
        self.server = server
        self.name = name
        self.connectionPool = connectionPool
    }
    
    public static func connect(to url: String) throws -> Future<Database> {
        let db = try Database(url)
        
        let connection = try db.server.reserveConnection(writing: false, authenticatedFor: nil)
        
        defer {
            db.server.returnConnection(connection)
        }
        
        return try connection.authenticate(to: db).map { _ in
            return db
        }
    }
    
    /// Initializes this Database with a connection String.
    ///
    /// Requires a path with a database name
    init(_ url: String, maxConnectionsPerServer maxConnections: Int = 100) throws {
        let path = url.characters.split(separator: "/", maxSplits: 2, omittingEmptySubsequences: true)
        
        guard path.count == 3, let dbname = path.last?.split(separator: "?")[0] else {
            throw MongoError.invalidDatabase("")
        }
        
        self.server = try Server(url)
        
        self.name = String(dbname)
    }
    
    /// A queue to prevent subscripting from creating multiple instances of the same database
    private static let subscriptQueue = DispatchQueue(label: "org.mongokitten.database.subscriptqueue", qos: DispatchQoS.userInitiated)
    
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
        return Database.subscriptQueue.sync {
            collections.clean()
            
            if let col = collections[collection]?.value {
                return col
            }
            
            let newC = Collection(named: collection, in: self)
            collections[collection] = Weak(newC)
            return newC
        }
    }
}

extension Database: CustomStringConvertible {
    /// A debugging string
    public var description: String {
        return "MongoKitten.Database<\(server.hostname)/\(self.name)>"
    }
}
