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
/// `MongoDatabase` is the primary entry point for interacting with a MongoDB database.
/// It provides functionality for managing collections, executing transactions, and performing database-level operations.
///
/// ## Connection Methods
/// There are two ways to connect to a MongoDB database:
/// - `connect`: Immediately establishes a connection and throws an error if unsuccessful
/// - `lazyConnect`: Defers connection until the first operation, useful during development
///
/// ## Basic Usage
/// ```swift
/// // Connect to a database
/// let db = try await MongoDatabase.connect(to: "mongodb://localhost/myapp")
///
/// // Access a collection
/// let users = db["users"]
///
/// // List all collections
/// let collections = try await db.listCollections()
/// ```
///
/// ## Transactions
/// The database supports MongoDB transactions for multi-document operations:
/// ```swift
/// let transaction = try await db.startTransaction(autoCommitChanges: false)
/// let users = transaction["users"]
/// // Perform operations...
/// try await transaction.commit()
/// ```
///
/// ## Logging and Tracing
/// The database supports structured logging and distributed tracing:
/// ```swift
/// // Add request-specific metadata
/// let dbWithMetadata = db.adoptingLogMetadata([
///     "request_id": "123"
/// ])
/// ```
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

    /// The name of the database in MongoDB
    public let name: String

    /// The connection pool used to communicate with MongoDB servers
    public let pool: MongoConnectionPool
    
    /// The logger instance used for database operations
    public var logger: Logger {
        pool.logger
    }

    /// The namespace used for executing database commands
    ///
    /// This is typically `$cmd` in the current database
    public var commandNamespace: MongoNamespace {
        return MongoNamespace(to: "$cmd", inDatabase: self.name)
    }
    
    /// Creates a new database instance with the specified logging metadata
    ///
    /// This is useful for adding request-specific context to logs:
    /// ```swift
    /// let dbWithRequestId = db.adoptingLogMetadata([
    ///     "request_id": "123",
    ///     "user_id": "456"
    /// ])
    /// ```
    ///
    /// - Parameter metadata: The logging metadata to attach to database operations
    /// - Returns: A new database instance with the specified metadata
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
    
    /// Connect to a MongoDB database using a connection string
    ///
    /// This method immediately attempts to establish a connection and will throw an error if unsuccessful.
    /// This is preferred in production as connection issues are discovered immediately.
    ///
    /// - Parameters:
    ///   - uri: A MongoDB connection string (e.g. "mongodb://localhost/myapp")
    ///   - logger: Optional logger for database operations
    /// - Returns: A connected database instance
    ///
    /// Example:
    /// ```swift
    /// let db = try await MongoDatabase.connect(
    ///     to: "mongodb://user:pass@localhost/myapp"
    /// )
    /// ```
    public static func connect(to uri: String, logger: Logger = Logger(label: "org.orlandos-nl.mongokitten")) async throws -> MongoDatabase {
        try await connect(to: ConnectionSettings(uri), logger: logger)
    }
    /// Connect lazily to a MongoDB database using a connection string
    ///
    /// Unlike `connect`, this method does not immediately establish a connection.
    /// The connection will be established when the first database operation is performed.
    /// This can be useful in development or testing scenarios where the database
    /// might not be immediately available.
    ///
    /// - Parameters:
    ///   - uri: A MongoDB connection string (e.g. "mongodb://localhost/myapp")
    ///   - logger: Optional logger for database operations
    /// - Returns: A database instance that will connect lazily
    public static func lazyConnect(to uri: String, logger: Logger = Logger(label: "org.orlandos-nl.mongokitten")) throws -> MongoDatabase {
        try lazyConnect(to: ConnectionSettings(uri), logger: logger)
    }
    
    /// Connect lazily to a MongoDB database using connection settings
    ///
    /// Unlike `connect`, this method does not immediately establish a connection.
    /// The connection will be established when the first database operation is performed.
    /// Use this when you need fine-grained control over connection parameters and
    /// want to defer the actual connection.
    ///
    /// - Parameters:
    ///   - settings: Connection settings including authentication and target database
    ///   - logger: Optional logger for database operations
    /// - Returns: A database instance that will connect lazily
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

    /// Connect to a MongoDB database using connection settings
    ///
    /// This method immediately attempts to establish a connection and will throw an error if unsuccessful.
    /// Use this when you need fine-grained control over connection parameters.
    ///
    /// - Parameters:
    ///   - settings: Connection settings including authentication and target database
    ///   - logger: Optional logger for database operations
    /// - Returns: A connected database instance
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

    /// Start a new MongoDB transaction
    ///
    /// Transactions allow you to execute multiple operations atomically.
    /// All operations within a transaction either succeed together or fail together.
    ///
    /// - Parameters:
    ///   - autoCommit: If true, the transaction will automatically commit after successful operations
    ///   - options: Session options for the transaction
    ///   - transactionOptions: Optional transaction-specific options
    /// - Returns: A transaction database that executes operations within the transaction
    /// - Throws: `MongoKittenError` if transactions are not supported by the server
    ///
    /// Example:
    /// ```swift
    /// let transaction = try await db.startTransaction(autoCommitChanges: false)
    /// 
    /// // All operations are part of the transaction
    /// let users = transaction["users"]
    /// try await users.insertOne(["name": "Alice"])
    /// 
    /// // Commit the transaction
    /// try await transaction.commit()
    /// ```
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

    /// Get a collection in this database
    ///
    /// Collections are analogous to tables in relational databases.
    /// They store documents and support CRUD operations.
    ///
    /// - Parameter collection: The name of the collection
    /// - Returns: A collection instance for performing operations
    ///
    /// Example:
    /// ```swift
    /// let users = db["users"]
    /// let products = db["products"]
    /// ```
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
    /// This method returns all collections that the authenticated user has access to.
    /// It cannot be used within a transaction.
    ///
    /// - Returns: An array of collections in this database
    /// - Throws: `MongoKittenError` if used within a transaction or if the operation fails
    ///
    /// Example:
    /// ```swift
    /// let collections = try await db.listCollections()
    /// for collection in collections {
    ///     print(collection.name)
    /// }
    /// ```
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

extension EventLoopFuture where Value: Sendable {
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
