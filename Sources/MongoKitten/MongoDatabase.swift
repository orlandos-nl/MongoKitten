import MongoClient
import Logging
import Foundation
import NIO

#if canImport(NIOTransportServices) && os(iOS)
import NIOTransportServices
#endif

/// A reference to a MongoDB database, over a ``MongoConnectionPool``.
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
    
    public var logger: Logger {
        pool.logger
    }

    /// The collection to execute commands on
    public var commandNamespace: MongoNamespace {
        return MongoNamespace(to: "$cmd", inDatabase: self.name)
    }

    internal init(named name: String, pool: MongoConnectionPool) {
        self.name = name
        self.pool = pool
    }
    
    /// Connect to the database at the given `uri` using ``MongoCluster``
    ///
    /// - parameter uri: A MongoDB URI that contains at least a database component
    ///
    /// - Note: LazyConnecting while failing to connect will still result in a usable object, though queries will fail.
    ///
    /// **Usage:**
    ///
    /// ```swift
    /// let database = MongoDatabase.lazyConnect(
    ///     to: "mongodb://localhost/myapp
    /// )
    /// ```
    public static func lazyConnect(to uri: String, logger: Logger = Logger(label: "org.orlandos-nl.mongokitten")) throws -> MongoDatabase {
        try lazyConnect(to: ConnectionSettings(uri), logger: logger)
    }

    /// Connect to the database at the given `uri` using ``MongoCluster``
    ///
    /// - parameter uri: A MongoDB URI that contains at least a database component
    ///
    /// **Usage:**
    ///
    /// ```swift
    /// let database = MongoDatabase.lazyConnect(
    ///     to: "mongodb://localhost/myapp
    /// )
    /// ```
    public static func connect(to uri: String, logger: Logger = Logger(label: "org.orlandos-nl.mongokitten")) async throws -> MongoDatabase {
        try await connect(to: ConnectionSettings(uri), logger: logger)
    }
    
    /// Connect to the database with the given settings _lazily_. You can also use `lazyConnect(_:on:)` to connect by using a connection string.
    ///
    /// Will postpone queries until initial discovery is complete. Since the cluster is lazily initialized, you'll only know of a failure in connecting (such as wrong credentials) during queries
    ///
    /// - Note: LazyConnecting while failing to connect will still result in a usable object, though queries will fail.
    ///
    /// - parameter settings: The connection settings, which must include a database name
    public static func lazyConnect(
        to settings: ConnectionSettings,
        logger: Logger = Logger(label: "org.orlandos-nl.mongokitten")
    ) throws -> MongoDatabase {
        guard let targetDatabase = settings.targetDatabase else {
            logger.critical("Cannot connect to MongoDB: No target database specified")
            throw MongoKittenError(.cannotConnect, reason: .noTargetDatabaseSpecified)
        }
        
        let cluster = try MongoCluster(lazyConnectingTo: settings, logger: logger)
        return MongoDatabase(named: targetDatabase, pool: cluster)
    }

    /// Connect to the database with the given settings. You can also use `connect(_:on:)` to connect by using a connection string.
    ///
    /// Will postpone queries until initial discovery is complete. Since the cluster is lazily initialized, you'll only know of a failure in connecting (such as wrong credentials) during queries
    ///
    /// - parameter settings: The connection settings, which must include a database name
    public static func connect(
        to settings: ConnectionSettings,
        logger: Logger = Logger(label: "org.orlandos-nl.mongokitten")
    ) async throws -> MongoDatabase {
        guard let targetDatabase = settings.targetDatabase else {
            logger.critical("Cannot connect to MongoDB: No target database specified")
            throw MongoKittenError(.cannotConnect, reason: .noTargetDatabaseSpecified)
        }

        let cluster = try await MongoCluster(connectingTo: settings, logger: logger)
        return MongoDatabase(named: targetDatabase, pool: cluster)
    }
    
    /// Creates a new tranasction provided the SessionOptions and optional TransactionOptions
    ///
    /// The TransactionDatabase that is created can be used like a normal Database for queries within transactions _only_
    /// Creating a TransactionCollection is done the same way it's created with a normal Database.
    ///
    /// ```swift
    /// let transaction = try await db.startTransaction(autoCommit: false)
    /// // This users object is under the same transaction
    /// let users = transaction["users"]
    /// ```
    ///
    /// - returns: A ``MongoTransactionDatabase`` which works just like a regular MongoDatabase, except all queries are under Matransaction.
    ///
    /// - Note: `startTransaction` only affects queries made on the database object returned from the `startTransaction` call.
    public func startTransaction(
        autoCommitChanges autoCommit: Bool,
        with options: MongoSessionOptions = .init(),
        transactionOptions: MongoTransactionOptions? = nil
    ) async throws -> MongoTransactionDatabase {
        let connection = try await pool.next(for: .writable)
        guard await connection.wireVersion?.supportsReplicaTransactions == true else {
            pool.logger.error("MongoDB transaction not supported by the server")
            throw MongoKittenError(.unsupportedFeatureByServer, reason: nil)
        }

        let newSession = self.pool.sessionManager.retainSession(with: options)
        let transaction = newSession.startTransaction(autocommit: autoCommit)
        
        let db = MongoTransactionDatabase(named: name, pool: connection)
        db.transaction = transaction
        db.session = newSession
        return db
    }

    /// Get a `MongoCollection` by providing a collection name as a `String`
    ///
    /// - parameter collection: The collection/bucket to return
    ///
    /// - returns: The requested collection in this database
    public subscript(collection: String) -> MongoCollection {
        let collection = MongoCollection(named: collection, in: self)
        collection.session = self.session
        collection.transaction = self.transaction
        return collection
    }

    /// Drops the current database, deleting the associated data files
    ///
    /// - see: https://docs.mongodb.com/manual/reference/command/dropDatabase
    public func drop() async throws {
        guard transaction == nil else {
            throw MongoKittenError(.unsupportedFeatureByServer, reason: .transactionForUnsupportedQuery)
        }
        
        let connection = try await pool.next(for: .writable)
        let reply = try await connection.executeEncodable(
            DropDatabaseCommand(),
            namespace: self.commandNamespace,
            in: self.transaction,
            sessionId: connection.implicitSessionId
        )
        try reply.assertOK()
    }

    /// Lists all collections your user has knowledge of
    ///
    /// Returns them as a MongoKitten Collection with you can query
    public func listCollections() async throws -> [MongoCollection] {
        guard transaction == nil else {
            throw MongoKittenError(.unsupportedFeatureByServer, reason: .transactionForUnsupportedQuery)
        }
        
        let connection = try await pool.next(for: .basic)
        let response = try await connection.executeCodable(
            ListCollections(),
            decodeAs: MongoCursorResponse.self,
            namespace: self.commandNamespace,
            in: self.transaction,
            sessionId: connection.implicitSessionId
        )
        
        let cursor = MongoCursor(
            reply: response.cursor,
            in: .administrativeCommand,
            connection: connection,
            session: connection.implicitSession,
            transaction: self.transaction
        ).decode(CollectionDescription.self)
        
        return try await cursor.drain().map { description in
            return MongoCollection(named: description.name, in: self)
        }
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

    /// Lists all databases your user has knowledge of in this cluster
    public func listDatabases() async throws -> [MongoDatabase] {
        let connection = try await next(for: .basic)
        let response = try await connection.executeCodable(
            ListDatabases(),
            decodeAs: ListDatabasesResponse.self,
            namespace: .administrativeCommand,
            sessionId: connection.implicitSessionId
        )
        
        return response.databases.map { description in
            return MongoDatabase(named: description.name, pool: self)
        }
    }
}
