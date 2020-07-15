import MongoClient
import Logging
import Foundation
import NIO

#if canImport(NIOTransportServices) && os(iOS)
import NIOTransportServices
#endif

/// A reference to a MongoDB database, over a `Connection`.
///
/// Databases hold collections of documents.
public class MongoDatabase {
    internal var transaction: MongoTransaction!
    public internal(set) var session: MongoClientSession?
    public var sessionId: SessionIdentifier? {
        return session?.sessionId
    }
    
    public var isInTransaction: Bool {
        return self.transaction != nil
    }

    /// The name of the database
    public let name: String

    public let pool: MongoConnectionPool

    /// The collection to execute commands on
    public var commandNamespace: MongoNamespace {
        return MongoNamespace(to: "$cmd", inDatabase: self.name)
    }
    
    public private(set) var hoppedEventLoop: EventLoop?

    /// The NIO event loop.
    public var eventLoop: EventLoop {
        return pool.eventLoop
    }

    internal init(named name: String, pool: MongoConnectionPool) {
        self.name = name
        self.pool = pool
    }
    
    public func hopped(to eventloop: EventLoop) -> MongoDatabase {
        let database = MongoDatabase(named: self.name, pool: self.pool)
        database.hoppedEventLoop = eventloop
        return database
    }

    /// A helper method that uses the normal `connect` method and awaits it. It creates an event loop group for you.
    ///
    /// It is not recommended to use `synchronousConnect` in a NIO environment (like Vapor 3), as it will create an event loop group for you.
    ///
    /// - parameter uri: A MongoDB URI that contains at least a database component
    /// - throws: Can throw for a variety of reasons, including an invalid connection string, failure to connect to the MongoDB database, etcetera.
    /// - returns: A connected database instance
    public static func synchronousConnect(_ uri: String) throws -> MongoDatabase {
        #if canImport(NIOTransportServices) && os(iOS)
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
        #if canImport(NIOTransportServices) && os(iOS)
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
    public static func connect(
        settings: ConnectionSettings,
        on group: _MongoPlatformEventLoopGroup,
        logger: Logger = .defaultMongoCore
    ) -> EventLoopFuture<MongoDatabase> {
        do {
            guard let targetDatabase = settings.targetDatabase else {
                logger.critical("Cannot connect to MongoDB: No target database specified")
                throw MongoKittenError(.cannotConnect, reason: .noTargetDatabaseSpecified)
            }
            
            let cluster = try MongoCluster(lazyConnectingTo: settings, on: group, logger: logger)
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
    public static func lazyConnect(
        settings: ConnectionSettings,
        on group: _MongoPlatformEventLoopGroup,
        logger: Logger = .defaultMongoCore
    ) throws -> MongoDatabase {
        guard let targetDatabase = settings.targetDatabase else {
            logger.critical("Cannot connect to MongoDB: No target database specified")
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

    @available(*, deprecated, message: "Change `autoCommitChanged` to `autoCommitChanges`")
    public func startTransaction(
        autoCommitChanged autoCommit: Bool,
        with options: MongoSessionOptions = .init(),
        transactionOptions: MongoTransactionOptions? = nil
    ) throws -> MongoTransactionDatabase {
        return try startTransaction(autoCommitChanges: autoCommit, with: options, transactionOptions: transactionOptions)
    }
    
    /// Creates a new tranasction provided the SessionOptions and optional TransactionOptions
    ///
    /// The TransactionDatabase that is created can be used like a normal Database for queries within transactions _only_
    /// Creating a TransactionCollection is done the same way it's created with a normal Database.
    public func startTransaction(
        autoCommitChanges autoCommit: Bool,
        with options: MongoSessionOptions = .init(),
        transactionOptions: MongoTransactionOptions? = nil
    ) throws -> MongoTransactionDatabase {
        guard pool.wireVersion?.supportsReplicaTransactions == true else {
            pool.logger.error("MongoDB transaction not supported by the server")
            throw MongoKittenError(.unsupportedFeatureByServer, reason: nil)
        }

        let newSession = self.pool.sessionManager.retainSession(with: options)
        let transaction = newSession.startTransaction(autocommit: autoCommit)
        
        let db = MongoTransactionDatabase(named: self.name, pool: self.pool)
        db.transaction = transaction
        db.session = newSession
        return db
    }
    
    private func makeTransactionError<T>() -> EventLoopFuture<T> {
        return eventLoop.makeFailedFuture(
            MongoKittenError(.unsupportedFeatureByServer, reason: .transactionForUnsupportedQuery)
        )
    }

    /// Get a `Collection` by providing a collection name as a `String`
    ///
    /// - parameter collection: The collection/bucket to return
    ///
    /// - returns: The requested collection in this database
    public subscript(collection: String) -> MongoCollection {
        let collection = MongoCollection(named: collection, in: self)
        collection.session = self.session
        collection.transaction = self.transaction
        collection.hoppedEventLoop = self.hoppedEventLoop
        return collection
    }

    /// Drops the current database, deleting the associated data files
    ///
    /// - see: https://docs.mongodb.com/manual/reference/command/dropDatabase
    public func drop() -> EventLoopFuture<Void> {
        guard transaction == nil else {
            return makeTransactionError()
        }
        
        return pool.next(for: .writable).flatMap { connection in
            return connection.executeCodable(
                DropDatabaseCommand(),
                namespace: self.commandNamespace,
                in: self.transaction,
                sessionId: connection.implicitSessionId
            ).flatMapThrowing { reply -> Void in
                try reply.assertOK()
            }
        }._mongoHop(to: hoppedEventLoop)
    }

    /// Lists all collections your user has knowledge of
    ///
    /// Returns them as a MongoKitten Collection with you can query
    public func listCollections() -> EventLoopFuture<[MongoCollection]> {
        guard transaction == nil else {
            return makeTransactionError()
        }
        
        return pool.next(for: .basic).flatMap { connection in
            return connection.executeCodable(
                ListCollections(),
                namespace: self.commandNamespace,
                in: self.transaction,
                sessionId: connection.implicitSessionId
            ).flatMap { reply in
                do {
                    let response = try MongoCursorResponse(reply: reply)
                    let cursor = MongoCursor(
                        reply: response.cursor,
                        in: .administrativeCommand,
                        connection: connection,
                        session: connection.implicitSession,
                        transaction: self.transaction
                    )
                    return cursor.decode(CollectionDescription.self).allResults().map { descriptions in
                        return descriptions.map { description in
                            return MongoCollection(named: description.name, in: self)
                        }
                    }
                } catch {
                    return connection.eventLoop.makeFailedFuture(error)
                }
            }
        }._mongoHop(to: hoppedEventLoop)
    }
}

extension EventLoopFuture {
    internal func _mongoHop(to eventLoop: EventLoop?) -> EventLoopFuture<Value> {
        guard let eventLoop = eventLoop else {
            return self
        }
        
        return self.hop(to: eventLoop)
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
    public func decodeReply<D: Decodable>(_ type: D.Type) -> EventLoopFuture<D> {
        return flatMapThrowing { reply in
            do {
                return try D(reply: reply)
            } catch {
                throw try MongoGenericErrorReply(reply: reply)
            }
        }
    }
}

extension EventLoopFuture where Value == Optional<Document> {
    public func decode<D: Decodable>(_ type: D.Type) -> EventLoopFuture<D?> {
        return flatMapThrowing { document in
            if let document = document {
                return try BSONDecoder().decode(type, from: document)
            } else {
                return nil
            }
        }
    }
}


extension MongoConnectionPool {
    public subscript(db: String) -> MongoDatabase {
        return MongoDatabase(named: db, pool: self)
    }

    public func listDatabases() -> EventLoopFuture<[MongoDatabase]> {
        return next(for: .basic).flatMap { connection in
            return connection.executeCodable(
                ListDatabases(),
                namespace: .administrativeCommand,
                sessionId: connection.implicitSessionId
            ).flatMapThrowing { reply in
                let response = try ListDatabasesResponse(reply: reply)

                return response.databases.map { description in
                    return MongoDatabase(named: description.name, pool: self)
                }
            }
        }
    }
}
