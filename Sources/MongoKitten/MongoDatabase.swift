import MongoClient
import Foundation
import NIO

#if canImport(NIOTransportServices)
import NIOTransportServices
#endif

/// A reference to a MongoDB database, over a `Connection`.
///
/// Databases hold collections of documents.
public class MongoDatabase {
    internal var transaction: Transaction!

    /// The name of the database
    public let name: String

    public let pool: MongoConnectionPool

    /// The collection to execute commands on
    internal var commandNamespace: MongoNamespace {
        return MongoNamespace(to: "$cmd", inDatabase: self.name)
    }

    /// The NIO event loop.
    public var eventLoop: EventLoop {
        return pool.eventLoop
    }

    internal init(named name: String, pool: MongoConnectionPool) {
        self.name = name
        self.pool = pool
    }

    /// A helper method that uses the normal `connect` method and awaits it. It creates an event loop group for you.
    ///
    /// It is not recommended to use `synchronousConnect` in a NIO environment (like Vapor 3), as it will create an event loop group for you.
    ///
    /// - parameter uri: A MongoDB URI that contains at least a database component
    /// - throws: Can throw for a variety of reasons, including an invalid connection string, failure to connect to the MongoDB database, etcetera.
    /// - returns: A connected database instance
    public static func synchronousConnect(_ uri: String) throws -> MongoDatabase {
        #if canImport(NIOTransportServices)
        let group = NIOTSEventLoopGroup(loopCount: 1, defaultQoS: .default)
        #else
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        #endif

        return try self.connect(uri, on: group).wait()
    }

    /// A helper method that uses the normal `connect` method with the given settings and awaits it. It creates an event loop group for you.
    ///
    /// It is not recommended to use `synchronousConnect` in a NIO environment (like Vapor 3), as it will create an event loop group for you.
    ///
    /// - parameter settings: The connection settings, which must include a database name
    /// - throws: Can throw for a variety of reasons, including an invalid connection string, failure to connect to the MongoDB database, etcetera.
    /// - returns: A connected database instance
    public static func synchronousConnect(settings: ConnectionSettings) throws -> MongoDatabase {
        #if canImport(NIOTransportServices)
        let group = NIOTSEventLoopGroup(loopCount: 1, defaultQoS: .default)
        #else
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        #endif

        return try self.connect(settings: settings, on: group).wait()
    }

    /// Connect to the database at the given `uri`
    ///
    /// Will postpone queries until initial discovery is complete. Since the cluster is lazily initialized, you'll only know of a failure in connecting (such as wrong credentials) during queries
    ///
    /// - parameter uri: A MongoDB URI that contains at least a database component
    /// - parameter loop: An EventLoop from NIO. If you want to use MongoKitten in a synchronous / non-NIO environment, use the `synchronousConnect` method.
    public static func connect(_ uri: String, on group: _MongoPlatformEventLoopGroup) -> EventLoopFuture<MongoDatabase> {
        do {
            let settings = try ConnectionSettings(uri)

            return connect(settings: settings, on: group)
        } catch {
            return group.next().makeFailedFuture(error)
        }
    }

    /// Connect to the database at the given `uri`
    ///
    /// - parameter uri: A MongoDB URI that contains at least a database component
    /// - parameter loop: An EventLoop from NIO. If you want to use MongoKitten in a synchronous / non-NIO environment, use the `synchronousConnect` method.
    public static func lazyConnect(_ uri: String, on loop: _MongoPlatformEventLoopGroup) throws -> MongoDatabase {
        let settings = try ConnectionSettings(uri)
        return try lazyConnect(settings: settings, on: loop)
    }

    /// Connect to the database with the given settings. You can also use `connect(_:on:)` to connect by using a connection string.
    ///
    /// - parameter settings: The connection settings, which must include a database name
    /// - parameter loop: An EventLoop from NIO. If you want to use MongoKitten in a synchronous / non-NIO environment, use the `synchronousConnect` method.
    public static func connect(settings: ConnectionSettings, on group: _MongoPlatformEventLoopGroup) -> EventLoopFuture<MongoDatabase> {
        do {
            guard let targetDatabase = settings.targetDatabase else {
                throw MongoKittenError(.cannotConnect, reason: .noTargetDatabaseSpecified)
            }
            
            let cluster = try MongoCluster(lazyConnectingTo: settings, on: group)
            return cluster.initialDiscovery.map {
                return MongoDatabase(named: targetDatabase, pool: cluster)
            }
        } catch {
            return group.next().makeFailedFuture(error)
        }
    }

    /// Connect to the database with the given settings _lazily_. You can also use `connect(_:on:)` to connect by using a connection string.
    ///
    /// Will postpone queries until initial discovery is complete. Since the cluster is lazily initialized, you'll only know of a failure in connecting (such as wrong credentials) during queries
    ///
    /// - parameter settings: The connection settings, which must include a database name
    /// - parameter loop: An EventLoop from NIO. If you want to use MongoKitten in a synchronous / non-NIO environment, use the `synchronousConnect` method.
    public static func lazyConnect(settings: ConnectionSettings, on group: _MongoPlatformEventLoopGroup) throws -> MongoDatabase {
        guard let targetDatabase = settings.targetDatabase else {
            throw MongoKittenError(.cannotConnect, reason: .noTargetDatabaseSpecified)
        }

        let cluster = try MongoCluster(lazyConnectingTo: settings, on: group)
        return MongoDatabase(named: targetDatabase, pool: cluster)
    }

    /// Stats a new session which can be used for retryable writes, transactions and more
    //    public func startSession(with options: SessionOptions) -> Database {
    //        let newSession = session.cluster.sessionManager.next(with: options, for: session.cluster)
    //        return Database(named: name, session: newSession)
    //    }

    /// Creates a new tranasction provided the SessionOptions and optional TransactionOptions
    ///
    /// The TransactionDatabase that is created can be used like a normal Database for queries within transactions _only_
    /// Creating a TransactionCollection is done the same way it's created with a normal Database.
//    public func startTransaction(with options: SessionOptions, transactionOptions: MongoTransactionOptions? = nil) throws -> TransactionDatabase {
//        guard pool.wireVersion?.supportsReplicaTransactions == true else {
//            throw MongoKittenError(.unsupportedFeatureByServer, reason: nil)
//        }
//
//        let newSession = sessionManager.next(with: options, for: session.pool)
//        let transactionOptions = transactionOptions ?? options.defaultTransactionOptions ?? MongoTransactionOptions()
//        let transaction = Transaction(
//            options: transactionOptions,
//            transactionId: newSession.serverSession.nextTransactionNumber()
//        )
//        return TransactionDatabase(named: name, session: newSession, transaction: transaction)
//    }

    /// Get a `Collection` by providing a collection name as a `String`
    ///
    /// - parameter collection: The collection/bucket to return
    ///
    /// - returns: The requested collection in this database
    public subscript(collection: String) -> MongoCollection {
        return MongoCollection(named: collection, in: self)
    }

    /// Drops the current database, deleting the associated data files
    ///
    /// - see: https://docs.mongodb.com/manual/reference/command/dropDatabase
    public func drop() -> EventLoopFuture<Void> {
        return pool.next(for: .writable).flatMap { connection in
            return connection.executeCodable(DropDatabaseCommand(), namespace: self.commandNamespace).flatMapThrowing { reply -> Void in
                try reply.assertOK()
            }
        }
    }

    /// Lists all collections your user has knowledge of
    ///
    /// Returns them as a MongoKitten Collection with you can query
    public func listCollections() -> EventLoopFuture<[MongoCollection]> {
        return pool.next(for: .basic).flatMap { connection in
            return connection.executeCodable(ListCollections(), namespace: self.commandNamespace).flatMap { reply in
                do {
                    let response = try MongoCursorResponse(reply: reply)
                    let cursor = MongoCursor(reply: response.cursor, in: .administrativeCommand, connection: connection)
                    return cursor.decode(CollectionDescription.self).allResults().map { descriptions in
                        return descriptions.map { description in
                            return MongoCollection(named: description.name, in: self)
                        }
                    }
                } catch {
                    return connection.eventLoop.makeFailedFuture(error)
                }
            }
        }
    }
}

internal extension MongoConnectionPoolRequest {
    static var writable: MongoConnectionPoolRequest {
        return MongoConnectionPoolRequest(writable: true)
    }

    static var basic: MongoConnectionPoolRequest {
        return MongoConnectionPoolRequest(writable: false)
    }
}

internal extension Decodable {
    init(reply: MongoServerReply) throws {
        self = try BSONDecoder().decode(Self.self, from: reply.getDocument())
    }
}

extension EventLoopFuture where Value == MongoServerReply {
    public func decode<D: Decodable>(_ type: D.Type) -> EventLoopFuture<D> {
        return flatMapThrowing(D.init(reply:))
    }
}

extension MongoConnectionPool {
    public subscript(db: String) -> MongoDatabase {
        return MongoDatabase(named: db, pool: self)
    }

    public func listDatabases() -> EventLoopFuture<[MongoDatabase]> {
        return next(for: .basic).flatMap { connection in
            return connection.executeCodable(ListDatabases(), namespace: .administrativeCommand).flatMapThrowing { reply in
                let response = try ListDatabasesResponse(reply: reply)

                return response.databases.map { description in
                    return MongoDatabase(named: description.name, pool: self)
                }
            }
        }
    }
}
