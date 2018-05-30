//
//  Database.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 24-05-18.
//

import BSON
import Foundation
import NIO

public final class Database {
    public let name: String
    public let connection: MongoDBConnection
    internal var cmd: Collection {
        return self["$cmd"]
    }
    
    public var objectIdGenerator: ObjectIdGenerator {
        return connection.sharedGenerator
    }
    
    var eventLoop: EventLoop {
        return connection.eventLoop
    }
    
    /// A helper method that uses the normal `connect` method and awaits it. It creates an event loop group for you.
    ///
    /// It is not recommended to use `synchronousConnect` in a NIO environment (like Vapor 3), as it will create an event loop group for you.
    ///
    /// - parameter uri: A MongoDB URI that contains at least a database component
    public static func synchronousConnect(_ uri: String) throws -> Database {
        let group = MultiThreadedEventLoopGroup(numThreads: 1)
        
        return try self.connect(uri, on: group.next()).wait()
    }
    
    /// Connect to the database with the given settings
    ///
    /// - parameter settings: The connection settings, which must include a database name
    /// - parameter loop: An EventLoop from NIO. If you want to use MongoKitten in a synchronous / non-NIO environment, use the `synchronousConnect` method.
    public static func connect(settings: ConnectionSettings, on loop: EventLoop) -> EventLoopFuture<Database> {
        do {
            guard let targetDatabase = settings.targetDatabase else {
                throw MongoKittenError(.unableToConnect, reason: .noTargetDatabaseSpecified)
            }
            
            return MongoDBConnection.connect(on: loop, settings: settings).map { connection -> Database in
                return connection[targetDatabase]
            }
        } catch {
            return loop.newFailedFuture(error: error)
        }
    }
    
    /// Connect to the database at the given `uri`
    ///
    /// - parameter uri: A MongoDB URI that contains at least a database component
    /// - parameter loop: An EventLoop from NIO. If you want to use MongoKitten in a synchronous / non-NIO environment, use the `synchronousConnect` method.
    public static func connect(_ uri: String, on loop: EventLoop) -> EventLoopFuture<Database> {
        do {
            let settings = try ConnectionSettings(uri)
            
            return connect(settings: settings, on: loop)
        } catch {
            return loop.newFailedFuture(error: error)
        }
    }
    
    internal init(named name: String, connection: MongoDBConnection) {
        self.name = name
        self.connection = connection
    }
    
    /// Get a `Collection` by providing a collection name as a `String`
    ///
    /// - parameter collection: The collection/bucket to return
    ///
    /// - returns: The requested collection in this database
    public subscript(collection: String) -> MongoKitten.Collection {
        return Collection(named: collection, in: self)
    }
    
    public func drop() -> EventLoopFuture<Void> {
        let command = AdministrativeCommand(command: DropDatabase(), on: cmd)
        
        return command.execute(on: connection).map { _ in }
    }
}
