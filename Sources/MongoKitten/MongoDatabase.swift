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

    internal init(named name: String, pool: MongoConnectionPool) {
        self.name = name
        self.pool = pool
    }
    
    /// Connect to the database at the given `uri`
    ///
    /// - parameter uri: A MongoDB URI that contains at least a database component
    public static func lazyConnect(to uri: String) throws -> MongoDatabase {
        try lazyConnect(to: ConnectionSettings(uri))
    }

    /// Connect to the database at the given `uri`
    ///
    /// - parameter uri: A MongoDB URI that contains at least a database component
    public static func connect(to uri: String) async throws -> MongoDatabase {
        try await connect(to: ConnectionSettings(uri))
    }
    
    /// Connect to the database with the given settings _lazily_. You can also use `lazyConnect(_:on:)` to connect by using a connection string.
    ///
    /// Will postpone queries until initial discovery is complete. Since the cluster is lazily initialized, you'll only know of a failure in connecting (such as wrong credentials) during queries
    ///
    /// - parameter settings: The connection settings, which must include a database name
    public static func lazyConnect(
        to settings: ConnectionSettings
    ) throws -> MongoDatabase {
        let logger = Logger(label: "org.openkitten.mongokitten")
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
        to settings: ConnectionSettings
    ) async throws -> MongoDatabase {
        let logger = Logger(label: "org.openkitten.mongokitten")
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
    public func startTransaction(
        autoCommitChanges autoCommit: Bool,
        with options: MongoSessionOptions = .init(),
        transactionOptions: MongoTransactionOptions? = nil
    ) async throws -> MongoTransactionDatabase {
        guard await pool.wireVersion?.supportsReplicaTransactions == true else {
            pool.logger.error("MongoDB transaction not supported by the server")
            throw MongoKittenError(.unsupportedFeatureByServer, reason: nil)
        }

        let newSession = await self.pool.sessionManager.retainSession(with: options)
        let transaction = newSession.startTransaction(autocommit: autoCommit)
        
        let db = MongoTransactionDatabase(named: name, pool: pool)
        db.transaction = transaction
        db.session = newSession
        return db
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

internal extension MongoConnectionPoolRequest {
    static var writable: MongoConnectionPoolRequest {
        return MongoConnectionPoolRequest(writable: true)
    }

    static var basic: MongoConnectionPoolRequest {
        return MongoConnectionPoolRequest(writable: false)
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
