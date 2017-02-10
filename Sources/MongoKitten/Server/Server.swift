//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

@_exported import BSON

import CryptoSwift
import Foundation
import LogKitten
import Dispatch

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// This file contains the low level code. This code is synchronous and is used by the async client API. //
//////////////////////////////////////////////////////////////////////////////////////////////////////////


/// A ResponseHandler is a closure that receives a MongoReply to process it
/// It's internal because ReplyMessages are an internal struct that is used for direct communication with MongoDB only
internal typealias ResponseHandler = ((Message) -> Void)

/// A server object is the core of MongoKitten as it's used to communicate to the server.
/// You can select a `Database` by subscripting an instance of this Server with a `String`.
public final class Server {
    /// The logging instance
    ///
    /// Do not reply on this. LogKitten is an alpha product and exclusively used by MongoKitten for exposing debugging information
    public var logger: FrameworkLogger
    
    /// All servers this library is connecting with
    internal var servers: [MongoHost] {
        get {
            return self.clientSettings.hosts
        }
        set {
            self.clientSettings.hosts = newValue
        }
    }
    
    /// Caches the password hash for this server's authentication details
    internal var hashedPassword: [UInt8]? = nil
    
    /// Handles errors within cursors
    public var cursorErrorHandler: ((Error)->()) = { doc in
        print(doc)
    }
    
    /// The ClientSettings used to connect to server(s)
    internal var clientSettings: ClientSettings
    
    /// The last Request we sent.. -1 if no request was sent
    internal var lastRequestID: Int32 = -1
    
    /// `MongoTCP` Socket bound to the MongoDB Server
    private var connections = [Connection]()

    /// Semaphore to use for safely managing connections
    private let connectionPoolSemaphore: DispatchSemaphore
    
    /// Lock to prevent multiple writes to/from the connections.
    private let connectionPoolLock = NSRecursiveLock()
    
    /// Lock to prevent multiple writes to/from the servers.
    private let hostPoolLock = NSLock()
    
    /// A lock to prevent multiple mutations of the maintainance tasks array
    private let maintainanceLoopLock = NSLock()
    
    /// Keeps track of the connections
    private var currentConnections = 0, maximumConnections = 100, maximumConnectionsPerHost = 100
    
    /// Did we initialize?
    private var isInitialized = false
    
    /// SlaveOK should be `true` when it's allowed to query Replica set slaves for data
    ///
    /// TODO: Currently not supported in MongoKitten but a planned feature. Hence that it's private
    /// TODO: MongoKitten should pass slaveOK together with the query in order for these requests to succeed
    private var slaveOK = false
    
    /// The default write concern at the Server level
    public var writeConcern: WriteConcern?
    
    /// The default read concern at the Server level
    public var readConcern: ReadConcern?
    
    /// The default Collation for collections at the Server level.
    public var collation: Collation? = nil
    
    /// The default timeout used for connections/queries
    internal var defaultTimeout: TimeInterval = 60
    
    /// Whether to verify the remote host or not, that is the question
    internal var sslVerify = true
    
    /// The server's details like the wire protocol version
    internal private(set) var serverData: (maxWriteBatchSize: Int32, maxWireVersion: Int32, minWireVersion: Int32, maxMessageSizeBytes: Int32)?
    
    /// The server's BuildInfo
    ///
    /// Do not access from the initialization process!
    public private(set) var buildInfo: BuildInfo! = nil
    
    /// This driver's information
    fileprivate let driverInformation: MongoDriverInformation
    
    /// Sets up the `Server` to connect to MongoDB.
    ///
    /// - Parameter clientSettings: The Client Settings
    /// - Throws: When we can't connect automatically, when the scheme/host is invalid and when we can't connect automatically
    public init(_ clientSettings: ClientSettings) throws {
        self.driverInformation = MongoDriverInformation(appName: clientSettings.applicationName)
        
        self.clientSettings = clientSettings
        self.connectionPoolSemaphore = DispatchSemaphore(value: self.clientSettings.maxConnectionsPerServer * self.clientSettings.hosts.count)
        self.defaultTimeout = self.clientSettings.defaultTimeout
        self.logger = Logger.forFramework(withIdentifier: "org.openkitten.mongokitten")
        
        if clientSettings.hosts.count > 1 {
            self.isReplica = true
            initializeReplica()
        } else {
            guard clientSettings.hosts.count == 1 else {
                throw MongoError.noServersAvailable
            }
            
            self.clientSettings.hosts[0].isPrimary = true
            self.clientSettings.hosts[0].online = true
            
            let connection = try makeConnection(toHost: self.clientSettings.hosts[0], authenticatedFor: nil)
            connection.used = true
            
            defer {
                returnConnection(connection)
            }
            
            connections.append(connection)
            
            let authDB = self[self.clientSettings.credentials?.database ?? "admin"]
            let cmd = authDB.cmd!
            var document: Document = [
                "isMaster": Int32(1)
            ]
            
            document.append(self.driverInformation, forKey: "client")
            
            let commandMessage = Message.Query(requestID: self.nextMessageID(), flags: [], collection: cmd, numbersToSkip: 0, numbersToReturn: 1, query: document, returnFields: nil)
            let response = try self.sendAndAwait(message: commandMessage, overConnection: connection, timeout: defaultTimeout)
            
            guard case .Reply(_, _, _, _, _, _, let documents) = response, let doc = documents.first else {
                throw InternalMongoError.incorrectReply(reply: response)
            }
            
            var maxMessageSizeBytes = doc["maxMessageSizeBytes"] as Int32? ?? 0
            if maxMessageSizeBytes == 0 {
                maxMessageSizeBytes = 48000000
            }
            
            self.serverData = (maxWriteBatchSize: doc[raw: "maxWriteBatchSize"]?.int32 ?? 1000, maxWireVersion: doc[raw: "maxWireVersion"]?.int32 ?? 4, minWireVersion: doc[raw: "minWireVersion"]?.int32 ?? 0, maxMessageSizeBytes: maxMessageSizeBytes)
        }
        
        self.buildInfo = try getBuildInfo()
        _ = try? logger.registerSubject(Document.self)
        self.connectionPoolMaintainanceQueue.async(execute: backgroundLoop)
    }
    
    /// Sets up the `Server` to connect to the specified URL.
    /// The `mongodb://` scheme is required as well as the host. Optionally youc an provide ausername + password. And if no port is specified `27017` is used.
    /// You can provide an alternative TCP Driver that complies to `MongoTCP`.
    /// This Server doesn't connect automatically. You need to either use the `connect` function yourself or specify the `automatically` parameter to be true.
    ///
    /// - parameter url: The MongoDB connection String.
    /// - parameter tcpDriver: The TCP Driver to be used to connect to the server. Recommended to change to an SSL supporting socket when connnecting over the public internet.
    ///
    /// - throws: When we can't connect automatically, when the scheme/host is invalid and when we can't connect automatically
    ///
    /// - parameter automatically: Whether to connect automatically
    convenience public init(mongoURL url: String, maxConnectionsPerServer maxConnections: Int = 100, defaultTimeout: TimeInterval = 30) throws {
        let clientSettings = try ClientSettings(mongoURL: url)
        try self.init(clientSettings)
    }
    
    /// Sets up the `Server` to connect to the specified location.`Server`
    /// You need to provide a host as IP address or as a hostname recognized by the client's DNS.
    /// - parameter at: The hostname/IP address of the MongoDB server
    /// - parameter port: The port we'll connect on. Defaults to 27017
    /// - parameter authentication: The optional authentication details we'll use when connecting to the server
    /// - parameter automatically: Connect automatically
    ///
    /// - throws: When we can’t connect automatically, when the scheme/host is invalid and when we can’t connect automatically
    convenience public init(hostname host: String, port: UInt16 = 27017, authenticatedAs authentication: MongoCredentials? = nil, maxConnectionsPerServer maxConnections: Int = 100, ssl sslSettings: SSLSettings? = nil) throws {
        let clientSettings = ClientSettings(host: MongoHost(hostname:host, port:port), sslSettings: sslSettings, credentials: authentication, maxConnectionsPerServer: maxConnections)
        try self.init(clientSettings)
    }
    
    /// An array maintaining all maintainance tasks
    var maintainanceLoopCalls = [(()->())]()
    
    /// An internal variable that determines whether we're connected to a replica set or sharded cluster
    var isReplica = false
    
    /// Tihs loop maintains all connections
    fileprivate func backgroundLoop() {
        maintainanceLoopLock.lock()
        for action in maintainanceLoopCalls {
            action()
        }
        
        maintainanceLoopCalls = []
        maintainanceLoopLock.unlock()
        
        Thread.sleep(forTimeInterval: 5)
        
        self.connectionPoolMaintainanceQueue.async(execute: backgroundLoop)
    }
    
    /// A MongoKitten internal variable that determines whether the driver is preparing for replica reinitialization
    var reinitializeReplica = false
    
    /// Initializes the replica set connection pool
    func initializeReplica() {
        logger.debug("Disconnecting all connections because we're reconnecting")
        _ = try? disconnect()
        
        self.servers = self.servers.map { host -> MongoHost in
            var host = host
            host.isPrimary = false
            self.connectionPoolLock.lock()
            
            defer {
                self.connectionPoolLock.unlock()
            }
            
            do {
                let authDB = self[clientSettings.credentials?.database ?? "admin"]
                let connection = try makeConnection(toHost: host, authenticatedFor: nil)
                connection.used = true
                
                defer {
                    returnConnection(connection)
                }
                
                connections.append(connection)
                
                let cmd = authDB.cmd!
                var document: Document = [
                    "isMaster": Int32(1)
                ]
                document.append(self.driverInformation, forKey: "client")
                
                let commandMessage = Message.Query(requestID: self.nextMessageID(), flags: [], collection: cmd, numbersToSkip: 0, numbersToReturn: 1, query: document, returnFields: nil)
                let response = try self.sendAndAwait(message: commandMessage, overConnection: connection, timeout: defaultTimeout)
                
                guard case .Reply(_, _, _, _, _, _, let documents) = response else {
                    throw InternalMongoError.incorrectReply(reply: response)
                }
                
                isMasterTest: if let doc = documents.first {
                    if doc["ismaster"] as Bool? == true {
                        logger.debug("Found a master connection at \(host.hostname):\(host.port)")
                        host.isPrimary = true
                        guard let batchSize = doc["maxWriteBatchSize"] as Int32?, let minWireVersion = doc["minWireVersion"] as Int32?, let maxWireVersion = doc["maxWireVersion"] as Int32? else {
                            logger.debug("No usable ismaster response found. Assuming defaults.")
                            serverData = (maxWriteBatchSize: 1000, maxWireVersion: 4, minWireVersion: 0, maxMessageSizeBytes: 48000000)
                            break isMasterTest
                        }
                        
                        var maxMessageSizeBytes = doc["maxMessageSizeBytes"] as Int32? ?? 0
                        if maxMessageSizeBytes == 0 {
                            maxMessageSizeBytes = 48000000
                        }
                        
                        serverData = (maxWriteBatchSize: batchSize, maxWireVersion: maxWireVersion, minWireVersion: minWireVersion, maxMessageSizeBytes: maxMessageSizeBytes)
                    }
                }
                
                connection.writable = host.isPrimary
                
                host.online = true
            } catch {
                logger.debug("Couldn't open a connection to MongoDB at \(host.hostname):\(host.port)")
                host.online = false
            }
            
            return host
        }
        
        reinitializeReplica = false
    }
    
    /// Creates a new connection to the best selected instance
    ///
    /// - parameter authenticatedFor: The Database that this connection is opened for. Prepares this Connection for authentication to this Database
    private func makeConnection(writing: Bool = true, authenticatedFor: Database?) throws -> Connection {
        logger.verbose("Attempting to create a new connection")
        self.hostPoolLock.lock()
        
        defer {
            self.hostPoolLock.unlock()
        }
        
        // Procedure to find best matching server
        
        // Takes a default server, which is the first primary server that is online
        guard var lowestOpenConnections = clientSettings.hosts.first(where: { $0.isPrimary && $0.online }) else {
            logger.verbose("No primary connection source has been found")
            throw MongoError.noServersAvailable
        }
        
        // If the connection has no need to be writable and slave reading is OK
        if !writing && slaveOK {
            // Find the next best match
            for server in clientSettings.hosts.filter({ !$0.isPrimary && $0.online && $0.openConnections < maximumConnectionsPerHost }) {
                // If this match is any good
                if server.openConnections < lowestOpenConnections.openConnections || (lowestOpenConnections.isPrimary && lowestOpenConnections.openConnections < server.openConnections - 2) {
                    // Make it the new selected server
                    lowestOpenConnections = server
                }
            }
        }
        
        // The connections mustn't be over the maximum specified connection count
        if lowestOpenConnections.openConnections >= maximumConnectionsPerHost {
            logger.verbose("Cannot create a new connection because the limit has been reached")
            throw MongoError.noServersAvailable
        }
        
        let connection = try Connection(clientSettings: self.clientSettings, writable: lowestOpenConnections.isPrimary, host: lowestOpenConnections, logger: self.logger) {
            self.hostPoolLock.lock()
            for (id, server) in self.servers.enumerated() where server == lowestOpenConnections {
                var host = server
                host.openConnections -= 1
                self.servers[id] = host
            }
            self.hostPoolLock.unlock()
        }
        
        // Check if the connection is successful
        guard connection.isConnected else {
            logger.info("The found connection source is offline")
            throw MongoError.notConnected
        }
        
        // Add the count to both the global and server connection pool
        currentConnections += 1
        
        for (id, server) in servers.enumerated() where server == lowestOpenConnections {
            lowestOpenConnections.openConnections += 1
            servers[id] = lowestOpenConnections
            logger.debug("Successfully created a new connection to the server at \(server.hostname):\(server.port)")
            return connection
        }
        
        // If the server couldn't be updated form some weird reason
        currentConnections -= 1
        logger.fatal("Couldn't update the connection pool's metadata")
        throw MongoError.internalInconsistency
    }
    
    /// Makes a new connection for the connection pool to a predefined host
    ///
    /// - parameter authenticatedFor: The Database that this connection is opened for. Prepares this Connection for authentication to this Database
    private func makeConnection(toHost host: MongoHost, authenticatedFor: Database?) throws -> Connection {
        let connection = try Connection(clientSettings: self.clientSettings, writable: host.isPrimary, host: host, logger: logger) {
            self.hostPoolLock.lock()
            for (id, server) in self.servers.enumerated() where server == host {
                var host = server
                host.openConnections -= 1
                self.servers[id] = host
            }
            self.hostPoolLock.unlock()
        }
        
        // Check if the connection is successful
        guard connection.isConnected else {
            logger.info("The found connection source is offline")
            throw MongoError.notConnected
        }
        
        connection.writable = host.isPrimary
        
        // Add the count to both the global and server connection pool
        
        self.hostPoolLock.lock()
        defer { self.hostPoolLock.unlock() }
        
        currentConnections += 1
        
        for (id, server) in servers.enumerated() where server == host {
            var host = host
            host.openConnections += 1
            servers[id] = host
            logger.debug("Successfully created a new connection to the server at \(server.hostname):\(server.port)")
            return connection
        }
        
        // If the server couldn't be updated form some weird reason
        logger.fatal("Couldn't update the connection pool's metadata")
        
        currentConnections -= 1
        throw MongoError.internalInconsistency
    }
    
    /// Reserves a connection to a database
    ///
    /// Can take a while when the connection pool is full.
    ///
    /// Takes the most efficient connection and prefers connections that are already authenticated to this database
    internal func reserveConnection(writing: Bool = false, authenticatedFor db: Database?, toHost host: (String, UInt16)? = nil) throws -> Connection {
        logger.verbose("Connection requested for database \(db)")
        var bestMatch: Connection? = nil
        
        connectionPoolLock.lock()
        
        // I needed to be creative here :P
        var disconnectionPool = [Connection]()
        
        // Filter any offline connections and put them in the disconnection pool
        // TODO: Move this to a better place?
        self.connections = self.connections.filter { connection in
            if !connection.isConnected {
                disconnectionPool.append(connection)
            }
            
            return connection.isConnected
        }
        
        connectionPoolLock.unlock()
        
        // If there are disconnected connections
        if disconnectionPool.count > 0 {
            connectionPoolMaintainanceQueue.async {
                // Close them for security sake
                disconnectionPool.forEach({
                    $0.close()
                })
                
                // If this is a replica server, set up a reconnect
                if self.isReplica {
                    self.maintainanceLoopLock.lock()
                    defer { self.maintainanceLoopLock.unlock() }
                    
                    self.logger.error("Disconnected from the replica set. Will attempt to reconnect")
                    
                    // If reinitializing is already happening, don't do it more than once
                    if !self.reinitializeReplica {
                        self.reinitializeReplica = true
                        self.maintainanceLoopCalls.append {
                            self.logger.info("Attempting to reconnect to the replica set.")
                            self.initializeReplica()
                        }
                    }
                }
            }
        }
        
        // Find all possible matches to create a connection to
        let matches = self.connections.filter {
            !$0.used && ((!writing && slaveOK) || $0.writable) && $0.isConnected
        }
        
        // If we need a specific database, find a connection optimal for that database I.E. already authenticated
        matching: if let db = db {
            if !writing {
                for match in matches {
                    if !match.writable && match.authenticatedDBs.contains(db.name) {
                        bestMatch = match
                        break matching
                    }
                }
            } else {
                if let match = matches.first(where: { $0.authenticatedDBs.contains(db.name) }) {
                    bestMatch = match
                }
            }
            // Otherwise, find any viable connection
        } else {
            bestMatch = matches.first(where: { ((!writing && slaveOK) || $0.writable) })
        }
        
        // If no optimal match could be found. Take the first one that we can find
        bestMatch = bestMatch ?? matches.first
        
        // This only fails if no available connection could be found
        guard let connection = bestMatch else {
            // Wait for a new one  if we can't create more connections
            guard currentConnections < clientSettings.maxConnectionsPerServer && (!writing || self.servers.first(where: { $0.isPrimary })?.openConnections ?? maximumConnectionsPerHost < maximumConnectionsPerHost) else {
                let timeout = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 10_000_000_000)
                
                guard case .success = self.connectionPoolSemaphore.wait(timeout: timeout) else {
                    throw MongoError.timeout
                }
                
                return try reserveConnection(writing: writing, authenticatedFor: db, toHost: host)
            }
            
            self.connectionPoolLock.lock()
            defer { self.connectionPoolLock.unlock() }
            
            // If we can create a new connection, create one
            let connection = try makeConnection(writing: writing, authenticatedFor: db)
            
            if let db = db {
                // On connection
                try connection.authenticate(toDatabase: db)
            }
            
            connections.append(connection)
            connection.used = true
            
            return connection
        }
        
        // If the connection isn't already authenticated to this DB
        if let db = db, !connection.authenticatedDBs.contains(db.name) {
            // Authenticate
            logger.info("Authenticating the connection to \(db)")
            try connection.authenticate(toDatabase: db)
            connection.authenticatedDBs.append(db.name)
        }
        
        connection.used = true
        
        return connection
    }
    
    /// Returns a connection to the Connection pool
    internal func returnConnection(_ connection: Connection) {
        self.connectionPoolLock.lock()
        
        defer {
            self.connectionPoolLock.unlock()
            self.connectionPoolSemaphore.signal()
        }
        
        connection.used = false
    }
    
    /// The database cache
    private var databaseCache: [String : Weak<Database>] = [:]
    
    /// Returns a `Database` instance referring to the database with the provided database name
    ///
    /// - parameter database: The database's name
    ///
    /// - returns: A database instance for the requested database
    public subscript(databaseName: String) -> Database {
        databaseCache.clean()
        
        let databaseName = databaseName.replacingOccurrences(of: ".", with: "")
        
        if let db = databaseCache[databaseName]?.value {
            return db
        }
        
        let db = Database(named: databaseName, atServer: self)
        
        databaseCache[databaseName] = Weak(db)
        return db
    }
    
    /// A dispatch queue for maintainance tasks
    private let connectionPoolMaintainanceQueue = DispatchQueue(label: "org.mongokitten.server.maintainanceQueue")
    
    /// A dispatch queue for incrementing the counter synchronously
    private let messageMutationQueue = DispatchQueue(label: "org.mongokitten.server.messageIncrementQueue")
    
    /// Generates a messageID for the next Message to be sent to the server
    ///
    /// - returns: The newly created ID for your message
    internal func nextMessageID() -> Int32 {
        var id: Int32 = 0
        messageMutationQueue.sync {
            lastRequestID += 1
            id = lastRequestID
        }
        return id
    }
    
    /// Are we currently connected?
    public var isConnected: Bool {
        guard connections.count > 0 else {
            return false
        }
        
        return self.servers.contains(where: { $0.online && $0.isPrimary })
    }
    
    /// Disconnects from the MongoDB server
    ///
    /// - throws: Unable to disconnect
    public func disconnect() throws {
        connectionPoolLock.lock()
        isInitialized = false
        
        for connection in connections {
            connection.close()
        }
        
        connections = []
        currentConnections = 0
        
        connectionPoolLock.unlock()
        hostPoolLock.lock()
        
        for (index, server) in self.servers.enumerated() {
            var server = server
            server.openConnections = 0
            self.servers[index] = server
        }
        
        hostPoolLock.unlock()
    }
    
    
    /// Sends a message to the server and waits until the server responded to the request.
    ///
    /// - parameter message: The message we're sending
    /// - parameter timeout: Timeout, in seconds
    ///
    /// - throws: Timeout reached or an internal MongoKitten error occured. In the second case, please file a ticket
    ///
    /// - returns: The reply from the server
    @discardableResult @warn_unqualified_access
    internal func sendAndAwait(message msg: Message, overConnection connection: Connection, timeout: TimeInterval = 0) throws -> Message {
        let timeout = timeout > 0 ? timeout : defaultTimeout
        
        let requestId = msg.requestID
        
        let semaphore = DispatchSemaphore(value: 0)
        
        connection.incomingMutateLock.lock()
        
        var reply: Message? = nil
        connection.waitingForResponses[requestId] = { message in
            reply = message
            semaphore.signal()
        }
        
        connection.incomingMutateLock.unlock()
        
        let messageData = try msg.generateData()
        
        do {
            try connection.client.send(data: messageData)
        } catch {
            logger.debug("Could not send data because of the following error: \"\(error)\"")
            connection.close()
        }
        
        guard semaphore.wait(timeout: DispatchTime.now() + timeout) == .success else {
            connection.incomingMutateLock.lock()
            connection.waitingForResponses[requestId] = nil
            connection.incomingMutateLock.unlock()
            logger.debug("Waiting for request \(requestId) timed out")
            throw MongoError.timeout
        }
        
        guard let theReply = reply else {
            logger.fatal("Reply was received but not found for id \(requestId)")
            // If we get here, something is very, very wrong.
            throw MongoError.internalInconsistency
        }
        
        return theReply
    }
    
    /// Sends a message to the server
    ///
    /// - parameter message: The message we're sending
    ///
    /// - throws: Unable to send the message over the socket
    ///
    /// - returns: The RequestID for this message that can be used to fetch the response
    @discardableResult @warn_unqualified_access
    internal func send(message msg: Message, overConnection connection: Connection) throws -> Int32 {
        let messageData = try msg.generateData()
        
        try connection.client.send(data: messageData)
        
        return msg.requestID
    }
    
    /// Provides a list of all existing databases along with basic statistics about them
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/listDatabases/#dbcmd.listDatabases
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func getDatabaseInfos() throws -> Document {
        let request: Document = ["listDatabases": 1]
        
        let reply = try self["admin"].execute(command: request, writing: false)
        
        return try firstDocument(in: reply)
    }
    
    /// Returns all existing databases on this server. **Requires access to the `admin` database**
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: All databases
    public func getDatabases() throws -> [Database] {
        let infos = try getDatabaseInfos()
        guard let databaseInfos = infos["databases"] as Document? else {
            throw MongoError.commandError(error: "No database Document found")
        }
        
        var databases = [Database]()
        for case (_, let dbDef) in databaseInfos {
            guard let dbDef = dbDef as? Document, let name = dbDef["name"] as String? else {
                logger.error("Fetching databases list was not successful because a database name was missing")
                logger.error(databaseInfos)
                throw MongoError.commandError(error: "No database name found")
            }
            
            databases.append(self[name])
        }
        
        return databases
    }
    
    /// Copies a database either from one mongod instance to the current mongod instance or within the current mongod
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/copydb/#dbcmd.copydb
    ///
    /// - parameter database: The database to copy
    /// - parameter otherDatabase: The other database
    /// - parameter user: The database's credentials
    /// - parameter remoteHost: The optional remote host to copy from
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func copy(database db: String, to otherDatabase: String, as user: (user: String, nonce: String, password: String)? = nil, at remoteHost: String? = nil, slaveOk: Bool? = nil) throws {
        var command: Document = [
            "copydb": Int32(1),
            ]
        
        if let fromHost = remoteHost {
            command["fromhost"] = fromHost
        }
        
        command["fromdb"] = db
        command["todb"] = otherDatabase
        
        if let slaveOk = slaveOk {
            command["slaveOk"] = slaveOk
        }
        
        if let user = user {
            command["username"] = user.user
            command["nonce"] = user.nonce
            
            let passHash = Digest.md5([UInt8]("\(user.user):mongo:\(user.password)".utf8)).toHexString()
            let key = Digest.md5([UInt8]("\(user.nonce)\(user.user)\(passHash))".utf8)).toHexString()
            command["key"] = key
        }
        
        let reply = try self["admin"].execute(command: command)
        let response = try firstDocument(in: reply)
        
        guard response["ok"] as Int? == 1 else {
            logger.error("copydb was not successful because of the following error")
            logger.error(response)
            throw MongoError.commandFailure(error: response)
        }
    }
    
    /// Clones a database from the specified MongoDB Connection URI
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/clone/#dbcmd.clone
    ///
    /// - parameter url: The URL
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func clone(from url: String) throws {
        let command: Document = [
            "clone": url
        ]
        
        let reply = try self["admin"].execute(command: command)
        let response = try firstDocument(in: reply)
        
        guard response["ok"] as Int? == 1 else {
            logger.error("clone was not successful because of the following error")
            logger.error(response)
            throw MongoError.commandFailure(error: response)
        }
    }
    
    /// Shuts down the MongoDB server
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/shutdown/#dbcmd.shutdown
    ///
    /// - parameter force: Force the s
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func shutdown(forced force: Bool? = nil) throws {
        var command: Document = [
            "shutdown": Int32(1)
        ]
        
        if let force = force {
            command["force"] = force
        }
        
        let response = try firstDocument(in: try self["$cmd"].execute(command: command))
        
        guard response["ok"] as Int? == 1 else {
            logger.error("shutdown was not successful because of the following error")
            logger.error(response)
            throw MongoError.commandFailure(error: response)
        }
    }
    
    /// Flushes all pending writes serverside
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/fsync/#dbcmd.fsync
    ///
    /// - parameter async: If true, dont block the server until the operation is finished
    /// - parameter block: Do we block writing in the meanwhile?
    public func fsync(async asynchronously: Bool? = nil, blocking block: Bool? = nil) throws {
        var command: Document = [
            "fsync": Int32(1)
        ]
        
        if let async = asynchronously {
            command["async"] = async
        }
        
        if let block = block {
            command["block"] = block
        }
        
        let reply = try self[self.clientSettings.credentials?.database ?? "admin"].execute(command: command, writing: true)
        let response = try firstDocument(in: reply)
        
        guard response["ok"] as Int? == 1 else {
            logger.error("fsync was not successful because of the following error")
            logger.error(response)
            throw MongoError.commandFailure(error: response)
        }
    }
    
    /// Gets the info from the user
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/usersInfo/#dbcmd.usersInfo
    ///
    /// - parameter user: The user's username
    /// - parameter database: The database to get the user from... otherwise uses admin
    /// - parameter showCredentials: Do you want to fetch the user's credentials
    /// - parameter showPrivileges: Do you want to fetch the user's privileges
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: The user's information (plus optionally the credentials and privileges)
    public func getUserInfo(forUserNamed user: String, inDatabase database: Database? = nil, showCredentials: Bool? = nil, showPrivileges: Bool? = nil) throws -> Document {
        var command: Document = [
            "usersInfo": ["user": user, "db": (database?.name ?? "admin")] as Document
        ]
        
        if let showCredentials = showCredentials {
            command["showCredentials"] = showCredentials
        }
        
        if let showPrivileges = showPrivileges {
            command["showPrivileges"] = showPrivileges
        }
        
        let db = database ?? self["admin"]
        
        let document = try firstDocument(in: try db.execute(command: command, writing: false))
        
        guard document["ok"] as Int? == 1 else {
            logger.error("usersInfo was not successful because of the following error")
            logger.error(document)
            throw MongoError.commandFailure(error: document)
        }
        
        guard let users = document["users"] as Document? else {
            logger.error("The user Document received from `usersInfo` could was not recognizable")
            logger.error(document)
            throw MongoError.commandError(error: "No users found")
        }
        
        return users
    }
    
    /// Returns the MongoDB Build Information
    internal func getBuildInfo() throws -> BuildInfo {
        var command: Document = [
            "buildInfo": Int32(1)
        ]
        
        let commandMessage = Message.Query(requestID: self.nextMessageID(), flags: [], collection: self["admin"]["$cmd"], numbersToSkip: 0, numbersToReturn: 1, query: [
            "buildInfo": Int32(1)
            ], returnFields: nil)
        
        let connection = try self.reserveConnection(authenticatedFor: nil)
        
        defer { returnConnection(connection) }
        
        let successResponse = try self.sendAndAwait(message: commandMessage, overConnection: connection)
        
        let successDocument = try firstDocument(in: successResponse)
        
        return try BuildInfo(fromDocument: successDocument)
    }
}

/// Helpful for debugging
extension Server : CustomStringConvertible {
    /// A textual representation of this `Server`
    public var description: String {
        return "MongoKitten.Server<\(hostname)>"
    }
    
    /// This server's hostname
    internal var hostname: String {
        return "mongodb://" + clientSettings.hosts.map { server in
            return "\(server.hostname):\(server.port)"
            }.joined(separator: ",")
    }
}

/// Iterates over all databases
extension Server: Sequence {
    /// Iterates over all databases
    public func makeIterator() -> AnyIterator<Database> {
        guard var databases = try? self.getDatabases() else {
            return AnyIterator { nil }
        }
        
        return AnyIterator {
            return databases.count > 0 ? databases.removeFirst() : nil
        }
    }
}
