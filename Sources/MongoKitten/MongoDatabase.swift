import Tracing
import MongoClient
import Logging
import Foundation
import NIO
import NIOConcurrencyHelpers

#if canImport(NIOTransportServices) && os(iOS)
import NIOTransportServices
#endif

/// A reference to a MongoDB database, over a `MongoConnectionPool`.
///
/// Databases hold collections of documents.
public class MongoDatabase: @unchecked Sendable {
    internal let transaction: MongoTransaction?
    public var activeTransaction: MongoTransaction? {
        transaction
    }
    public let session: MongoClientSession?

    private let _span: NIOLockedValueBox<(any Span)?>
    internal var span: (any Span)? {
        get { _span.withLockedValue { $0 } }
        set { _span.withLockedValue { $0 = newValue } }
    }
    internal var context: ServiceContext? {
        span?.context
    }
    private let _logMetadata: NIOLockedValueBox<Logger.Metadata?>
    public var logMetadata: Logger.Metadata? {
        get { _logMetadata.withLockedValue { $0 } }
        set { _logMetadata.withLockedValue { $0 = newValue } }
    }
    
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
    
    public func adoptingLogMetadata(_ metadata: Logger.Metadata) -> MongoDatabase {
        let copy = MongoDatabase(
            named: name,
            pool: pool,
            transaction: transaction,
            session: session
        )
        copy.logMetadata = metadata
        return copy
    }

    internal init(
        named name: String,
        pool: MongoConnectionPool,
        span: (any Span)? = nil,
        transaction: MongoTransaction?,
        session: MongoClientSession?
    ) {
        self.name = name
        self.pool = pool
        self._span = NIOLockedValueBox(span)
        self._logMetadata = NIOLockedValueBox(nil)
        self.transaction = transaction
        self.session = session
    }

    deinit { span?.end() }
    
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
        return MongoDatabase(
            named: targetDatabase,
            pool: cluster,
            transaction: nil,
            session: nil
        )
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
        return MongoDatabase(
            named: targetDatabase,
            pool: cluster,
            transaction: nil,
            session: nil
        )
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

        let span = InstrumentationSystem.tracer.startAnySpan("Transaction(\(transaction.number))")
        return MongoTransactionDatabase(
            named: name,
            pool: connection,
            span: span,
            transaction: transaction,
            session: newSession
        )
    }

    /// Get a `MongoCollection` by providing a collection name as a `String`
    ///
    /// - parameter collection: The collection/bucket to return
    ///
    /// - returns: The requested collection in this database
    public subscript(collection: String) -> MongoCollection {
        MongoCollection(
            named: collection,
            in: self,
            context: context,
            transaction: self.transaction,
            session: self.session
        )
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
            sessionId: connection.implicitSessionId,
            logMetadata: logMetadata,
            traceLabel: "DropDatabase"
        )
        try reply.assertOK()
    }

    /// Lists all collections your user has knowledge of
    ///
    /// - Returns: All MongoKitten Collection which you can query
    /// 
    /// See https://docs.mongodb.com/manual/reference/command/listCollections/
    public func listCollections() async throws -> [MongoCollection] {
        guard transaction == nil else {
            throw MongoKittenError(.unsupportedFeatureByServer, reason: .transactionForUnsupportedQuery)
        }
        
        let connection = try await pool.next(for: .basic)
        let span = InstrumentationSystem.tracer.startAnySpan("ListCollections")
        let response = try await connection.executeCodable(
            ListCollections(),
            decodeAs: MongoCursorResponse.self,
            namespace: self.commandNamespace,
            in: self.transaction,
            sessionId: connection.implicitSessionId,
            logMetadata: logMetadata,
            traceLabel: "ListCollections",
            serviceContext: span.context
        )
        
        let cursor = MongoCursor(
            reply: response.cursor,
            in: .administrativeCommand,
            connection: connection,
            session: connection.implicitSession,
            transaction: self.transaction,
            traceLabel: "ListCollections",
            context: span.context
        ).decode(CollectionDescription.self)
        
        return try await cursor.drain().map { description in
            return MongoCollection(
                named: description.name,
                in: self,
                context: context,
                transaction: self.transaction,
                session: self.session
            )
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
    /// Decodes a `Decodable` type from the `Document` in this `EventLoopFuture`
    public func decode<D: Decodable>(_ type: D.Type) -> EventLoopFuture<D?> {
        return flatMapThrowing { document in
            if let document = document {
                return try FastBSONDecoder().decode(type, from: document)
            } else {
                return nil
            }
        }
    }
}

extension MongoConnectionPool {
    public subscript(db: String) -> MongoDatabase {
        return MongoDatabase(
            named: db,
            pool: self,
            transaction: nil,
            session: nil
        )
    }

    /// Lists all databases your user has knowledge of in this cluster
    public func listDatabases() async throws -> [MongoDatabase] {
        let connection = try await next(for: .basic)
        let response = try await connection.executeCodable(
            ListDatabases(),
            decodeAs: ListDatabasesResponse.self,
            namespace: .administrativeCommand,
            sessionId: connection.implicitSessionId,
            traceLabel: "ListDatabases"
        )
        
        return response.databases.map { description in
            return MongoDatabase(
                named: description.name,
                pool: self,
                transaction: nil,
                session: nil
            )
        }
    }
}
