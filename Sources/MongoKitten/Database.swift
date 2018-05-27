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
    
    public static func connect(_ uri: String, on group: EventLoopGroup) -> EventLoopFuture<Database> {
        let loop = group.next()
        
        do {
            let settings = try ConnectionSettings(uri)
            
            guard let targetDatabase = settings.targetDatabase else {
                throw MongoKittenError(.unableToConnect, reason: .noTargetDatabaseSpecified)
            }
            
            return MongoDBConnection.connect(on: group, settings: settings).map { connection -> Database in
                return connection[targetDatabase]
            }
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
