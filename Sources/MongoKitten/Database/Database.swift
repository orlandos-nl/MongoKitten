//
//  Database.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 27/01/16.
//  Copyright © 2016 OpenKitten. All rights reserved.
//

import Foundation
import BSON
import Dispatch
import LogKitten

/// A Mongo Database. Cannot be publically initialized.
/// But you can get a database object by subscripting `Server` with a `String` as the database name
public final class Database {
    /// The `Server` that this Database is a part of
    public let server: Server
    
    /// The database's name
    public let name: String
    
    var logger: FrameworkLogger {
        return server.logger
    }
    
    /// The default ReadConcern for collections in this Database.
    ///
    /// When a ReadConcern is provided in the method call it'll still override this
    private var defaultReadConcern: ReadConcern? = nil
    
    /// The default WriteConcern for collections in this Database.
    ///
    /// When a WriteConcern is provided in the method call it'll still override this
    private var defaultWriteConcern: WriteConcern? = nil
    
    /// Sets or gets the default write concern at the database level
    public var writeConcern: WriteConcern? {
        get {
            return self.defaultWriteConcern ?? server.writeConcern
        }
        set {
            self.defaultWriteConcern = newValue
        }
    }
    
    /// Sets or gets the default read concern at the database level
    public var readConcern: ReadConcern? {
        get {
            return self.defaultReadConcern ?? server.readConcern
        }
        set {
            self.defaultReadConcern = newValue
        }
    }
    
    /// The default Collation for collections in this Database.
    ///
    /// When a Collation is provided in the method call it'll still override this
    private var defaultCollation: Collation? = nil
    
    /// Sets or gets the default collation at the database level
    public var collation: Collation? {
        get {
            return self.defaultCollation ?? server.collation
        }
        set {
            self.defaultCollation = newValue
        }
    }
    
    /// A cache of all collections in this Database.
    ///
    /// Mainly used for keeping track of event listeners
    private var collections = [String: Weak<Collection>]()
    
    #if Xcode
    /// XCode quick look debugging
    func debugQuickLookObject() -> AnyObject {
        var userInfo = ""
        
        if let username = server.clientSettings.credentials?.username {
            userInfo = "\(username):*********@"
        }
        
        var databaseData = ""
        
        if let collections = try? Array(self.listCollections()) {
            databaseData = "Collection count: \(collections.count)\n"
            for collection in collections {
                databaseData.append("- \(collection.name)\n")
            }
        } else {
            databaseData = "Unable to fetch database data"
        }
        
        return NSString(string: "mongodb://\(userInfo)\(server.hostname)/\(self.name)\n\n\(databaseData)")
    }
    #endif
    
    /// Initialise this database object
    ///
    /// - parameter database: The database to use
    /// - parameter server: The `Server` on which this database exists
    public init(named name: String, atServer server: Server) {
        self.server = server
        self.name = name
        self.cmd = Collection(named: "$cmd", in: self)
    }
    
    /// Initializes this Database with a connection String.
    ///
    /// Requires a path with a databasee name
    public init(mongoURL url: String, usingTcpDriver driver: MongoTCP.Type? = nil, maxConnectionsPerServer maxConnections: Int = 100) throws {
        let path = url.characters.split(separator: "/", maxSplits: 2, omittingEmptySubsequences: true)
        
        guard path.count == 3, let dbname = path.last?.split(separator: "?")[0] else {
            throw MongoError.invalidDatabase("")
        }
        
        self.server = try Server(mongoURL: url, maxConnectionsPerServer: maxConnections)
        
        self.name = String(dbname)
        
        self.cmd = Collection(named: "$cmd", in: self)
        
        let connection = try server.reserveConnection(writing: false, authenticatedFor: nil)
        
        defer {
            server.returnConnection(connection)
        }
        
        try connection.authenticate(toDatabase: self)
    }
    
    /// A queue to prevent subscripting from creating multiple instances of the same database
    private static let subscriptQueue = DispatchQueue(label: "org.mongokitten.database.subscriptqueue")
    
    /// Creates a GridFS collection in this database
    public func makeGridFS(named name: String = "fs") throws -> GridFS {
        return try GridFS(inDatabase: self, named: name)
    }
    
    /// Get a `Collection` by providing a collection name as a `String`
    ///
    /// - parameter collection: The collection/bucket to return
    ///
    /// - returns: The requested collection in this database
    public subscript (collection: String) -> Collection {
        var c: Collection!
        Database.subscriptQueue.sync {
            collections.clean()
            
            if let col = collections[collection]?.value {
                c = col
                return
            }
            
            c = Collection(named: collection, in: self)
            collections[collection] = Weak(c)
        }
        return c
    }
    
    /// Stores the $cmd collection to reduce the load on the collection subscript
    internal private(set) var cmd: Collection! = nil
    
    /// Executes a command `Document` on this database using a query message
    ///
    /// - parameter command: The command `Document` to execute
    /// - parameter timeout: The timeout in seconds for listening for a response
    ///
    /// - returns: A `Message` containing the response
    @discardableResult
    public func execute(dbCommand document: Document, until timeout: TimeInterval = 0, writing: Bool = true) throws -> [Document] {
        let timeout = timeout > 0 ? timeout : server.defaultTimeout
        
        let connection = try server.reserveConnection(writing: writing, authenticatedFor: self)
        
        defer {
            server.returnConnection(connection)
        }
        
        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: cmd, numbersToSkip: 0, numbersToReturn: 1, query: document, returnFields: nil)
        return try allDocuments(in: try server.sendAndAwait(message: commandMessage, overConnection: connection, timeout: timeout))
    }
    
    /// Executes a command `Document` on this database using a query message
    ///
    /// - parameter command: The command `Document` to execute
    /// - parameter timeout: The timeout in seconds for listening for a response
    ///
    /// - returns: A `Message` containing the response
    @discardableResult
    internal func execute(command document: Document, until timeout: TimeInterval = 0, writing: Bool = true) throws -> Message {
        let timeout = timeout > 0 ? timeout : server.defaultTimeout
        
        let connection = try server.reserveConnection(writing: writing, authenticatedFor: self)
        
        defer {
            server.returnConnection(connection)
        }
        
        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: cmd, numbersToSkip: 0, numbersToReturn: 1, query: document, returnFields: nil)
        return try server.sendAndAwait(message: commandMessage, overConnection: connection, timeout: timeout)
    }
    
    /// Returns a document that describes the role of the mongod instance.
    ///
    ///If the instance is a member of a replica set, then isMaster returns a subset of the replica set configuration and status including whether or not the instance is the primary of the replica set.
    ///
    /// When sent to a mongod instance that is not a member of a replica set, isMaster returns a subset of this information.
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/isMaster/#dbcmd.isMaster
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: `ismaster` response Document
    internal func isMaster() throws -> Document {
        let response = try self.execute(command: ["isMaster": Int32(1)])
        
        return try firstDocument(in: response)
    }
}

extension Database: CustomStringConvertible {
    /// A debugging string
    public var description: String {
        return "MongoKitten.Database<\(server.hostname)/\(self.name)>"
    }
}

extension Database : Sequence {
    /// Iterates over all collections in this database
    public func makeIterator() -> AnyIterator<Collection> {
        let collections = try? self.listCollections().makeIterator()
        
        return AnyIterator {
            return collections?.next()
        }
    }
}
