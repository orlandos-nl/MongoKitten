
//
//  NewDatabase.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 24/01/16.
//  Copyright © 2016 OpenKitten. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import Socks
import TLS

public let DefaultTCPClient: MongoTCP.Type = Socks.TCPClient.self
public let DefaultSSLTCPClient: MongoTCP.Type = TLS.Socket.self

@_exported import BSON

import Foundation
import CryptoKitten
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
public final class Server: Framework {
    public var logKittenID: UInt8?
    public let name = "MongoKitten"
    public var logger: Logger = Logger.default {
        didSet {
            logger.registerFramework(self)
            _ = try? logger.registerSubject(Document.self, forFramework: self)
        }
    }
    
    class Connection {
        let logger: Framework
        let client: MongoTCP
        let buffer = TCPBuffer()
        var used = false
        var writable = false
        var authenticatedDBs: [String] = []
        public var isConnected: Bool {
            return client.isConnected
        }
        var onClose: (()->())
        let host: (address: String, port: UInt16)
        
        init(client: MongoTCP, writable: Bool, host: (address: String, port: UInt16), logger: Framework, onClose: @escaping (()->())) {
            self.client = client
            self.writable = writable
            self.onClose = onClose
            self.host = host
            self.logger = logger
            Connection.receiveQueue.async(execute: backgroundLoop)
        }
        
        func authenticate(toDatabase db: Database) throws {
            if let details = db.server.authDetails {
                do {
                    let protocolVersion = db.server.serverData?.maxWireVersion ?? 0
                    
                    if protocolVersion >= 3 {
                        try db.authenticate(SASL: details, usingConnection: self)
                    } else {
                        try db.authenticate(mongoCR: details, usingConnection: self)
                    }
                    
                    self.authenticatedDBs.append(db.name)
                } catch { }
            }
        }
        
        private static let receiveQueue = DispatchQueue(label: "org.mongokitten.server.receiveQueue", attributes: .concurrent)
        
        fileprivate var waitingForResponses = [Int32:(Message)->()]()
        
        /// A cache for incoming responses
        fileprivate var incomingMutateLock = NSLock()
        
        /// Receives response messages from the server and gives them to the callback closure
        /// After handling the response with the closure it removes the closure
        fileprivate func backgroundLoop() {
            do {
                try self.receive()
            } catch {
                // A receive failure is to be expected if the socket has been closed
                incomingMutateLock.lock()
                if self.isConnected {
                    logger.fatal("The MongoKitten background loop encountered an error and has stopped: \(error)")
                    logger.fatal("Please file a report on https://github.com/openkitten/mongokitten")
                }
                incomingMutateLock.unlock()
                
                return
            }
            
            Connection.receiveQueue.async(execute: backgroundLoop)
        }
        
        func close() {
            _ = try? client.close()
            onClose()
        }
        
        /// Called by the server thread to handle MongoDB Wire messages
        ///
        /// - parameter bufferSize: The amount of bytes to fetch at a time
        ///
        /// - throws: Unable to receive or parse the reply
        private func receive(bufferSize: Int = 1024) throws {
            // TODO: Respect bufferSize
            let incomingBuffer: [UInt8] = try client.receive()
            buffer.data += incomingBuffer
            
            while buffer.data.count >= 36 {
                let length = Int(try fromBytes(buffer.data[0...3]) as Int32)
                
                guard length <= buffer.data.count else {
                    // Ignore: Wait for more data
                    return
                }
                
                let responseData = buffer.data[0..<length]*
                let responseId = try fromBytes(buffer.data[8...11]) as Int32
                let reply = try Message.makeReply(from: responseData)
                
                if let closure = waitingForResponses[responseId] {
                    closure(reply)
                    waitingForResponses[responseId] = nil
                } else {
                    
                }
                
                buffer.data.removeSubrange(0..<length)
            }
        }
    }
    
    public var cursorErrorHandler: ((Error)->()) = { doc in
        print(doc)
    }
    
    /// The authentication details that are used to connect with the MongoDB server
    internal let authDetails: (username: String, password: String, against: String)?
    
    /// The last Request we sent.. -1 if no request was sent
    internal var lastRequestID: Int32 = -1
    
    /// `MongoTCP` Socket bound to the MongoDB Server
    private var connections = [Connection]()
    
    /// `MongoTCP` class to use for clients
    public let tcpType: MongoTCP.Type
    
    /// Semaphore to use for safely managing connections
    private let connectionPoolSemaphore: DispatchSemaphore
    
    /// Lock to prevent multiple writes to/from the connections.
    private let connectionPoolLock = NSRecursiveLock()
    
    /// Lock to prevent multiple writes to/from the servers.
    private let hostPoolLock = NSLock()
    
    private let maintainanceLoopLock = NSLock()
    
    /// Keeps track of the connections
    private var currentConnections = 0, maximumConnections = 1, maximumConnectionsPerHost = 1
    
    /// Did we initialize?
    private var isInitialized = false
    
    private var slaveOK = false
    
    internal var defaultTimeout: TimeInterval
    
    /// The server's hostname/IP and port to connect to
    public var servers: [(host: String, port: UInt16, openConnections: Int, isPrimary: Bool, online: Bool)]
    
    internal private(set) var serverData: (maxWriteBatchSize: Int32, maxWireVersion: Int32, minWireVersion: Int32, maxMessageSizeBytes: Int32)?
    
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
    public init(mongoURL url: String, usingTcpDriver tcpDriver: MongoTCP.Type? = nil, maxConnectionsPerServer maxConnections: Int = 10, defaultTimeout: TimeInterval
         = 30) throws {
        var url = url
        guard url.characters.starts(with: "mongodb://".characters) else {
            throw MongoError.noMongoDBSchema
        }
        
        url.characters.removeFirst("mongodb://".characters.count)
        
        let parts = url.characters.split(separator: "@")
        
        guard parts.count <= 2 else {
            throw MongoError.invalidURI(uri: url)
        }
        
        url = parts.count == 2 ? String(parts[1]) : String(parts[0])
        
        let queryParts = url.characters.split(separator: "?")
        
        url = String(queryParts[0])
        
        var queries = [String: String]()
        
        if queryParts.count == 2 {
            loop: for keyValue in String(queryParts[1]).characters.split(separator: "&") {
                let keyValue = Array(keyValue).split(separator: "=")
                
                queries[String(keyValue[0])] = keyValue.count == 2 ? String(keyValue[1]) : ""
            }
        }
        
        var username: String? = nil
        var password: String? = nil
        var path: String? = nil
        
        if parts.count == 2 {
            let userString = parts[0]
            let userParts = userString.split(separator: ":")
            
            guard userParts.count == 2 else {
                throw MongoError.invalidURI(uri: url)
            }
            
            username = String(userParts[0]).removingPercentEncoding
            password = String(userParts[1]).removingPercentEncoding
        }
        
        let urlSplitWithPath = url.characters.split(separator: "/")
        
        url = String(urlSplitWithPath[0])
        path = urlSplitWithPath.count == 2 ? String(urlSplitWithPath[1]) : nil
        
        var authentication: (username: String, password: String, against: String)? = nil
        
        if let user = username?.removingPercentEncoding, let pass = password?.removingPercentEncoding {
            authentication = (username: user, password: pass, against: path ?? "admin")
        }
        
        let hosts = url.characters.split(separator: ",").map { host -> (String, UInt16, Int, Bool, Bool) in
            let hostSplit = host.split(separator: ":")
            var port: UInt16 = 27017
            
            if hostSplit.count == 2 {
                port = UInt16(String(hostSplit[1])) ?? 27017
            }
            
            let hostname = String(hostSplit[0])
            
            return (hostname, port, 0, false, false)
        }
        
        let ssl = queries.keys.contains("ssl")
        
        self.tcpType = tcpDriver ?? (ssl ? DefaultSSLTCPClient : DefaultTCPClient)
        self.maximumConnections = maxConnections * hosts.count
        self.authDetails = authentication
        self.maximumConnectionsPerHost = maxConnections
        self.connectionPoolSemaphore = DispatchSemaphore(value: maxConnections * hosts.count)
        self.servers = hosts
        self.defaultTimeout = defaultTimeout
        
        if servers.count > 1 {
            self.isReplica = true
            initializeReplica()
        } else {
            guard servers.count == 1 else {
                throw MongoError.noServersAvailable
            }
            
            servers[0].isPrimary = true
            
            let authDB = self[authentication?.against ?? "admin"]
            let doc = try authDB.isMaster()
            
            guard let batchSize = doc["maxWriteBatchSize"] as Int32?, let minWireVersion = doc["minWireVersion"] as Int32?, let maxWireVersion = doc["maxWireVersion"] as Int32? else {
                serverData = (maxWriteBatchSize: 1000, maxWireVersion: 4, minWireVersion: 0, maxMessageSizeBytes: 48000000)
                return
            }
            
            var maxMessageSizeBytes = doc["maxMessageSizeBytes"] as Int32? ?? 0
            if maxMessageSizeBytes == 0 {
                maxMessageSizeBytes = 48000000
            }
            
            self.serverData = (maxWriteBatchSize: batchSize, maxWireVersion: maxWireVersion, minWireVersion: minWireVersion, maxMessageSizeBytes: maxMessageSizeBytes)
        }
        
        self.connectionPoolMaintainanceQueue.async(execute: backgroundLoop)
    }
    
    var maintainanceLoopCalls = [(()->())]()
    var isReplica = false
    
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
    
    var reinitializeReplica = false
    
    func initializeReplica() {
        debug("Disconnecting all connections because we're reconnecting")
        _ = try? disconnect()
        
        self.servers = self.servers.map { host -> (host: String, port: UInt16, openConnections: Int, isPrimary: Bool, online: Bool) in
            var host = host
            host.isPrimary = false
            self.connectionPoolLock.lock()
            
            defer {
                self.connectionPoolLock.unlock()
            }
            
            do {
                let authDB = self[authDetails?.against ?? "admin"]
                let connection = try makeConnection(toHost: host, authenticatedFor: authDB)
                connection.used = true
                
                defer {
                    returnConnection(connection)
                }
                
                connections.append(connection)
                
                let cmd = authDB["$cmd"]
                let document: Document = [
                    "isMaster": Int32(1)
                ]
                
                let commandMessage = Message.Query(requestID: self.nextMessageID(), flags: [], collection: cmd, numbersToSkip: 0, numbersToReturn: 1, query: document, returnFields: nil)
                let response = try self.sendAndAwait(message: commandMessage, overConnection: connection, timeout: defaultTimeout)
                
                guard case .Reply(_, _, _, _, _, _, let documents) = response else {
                    throw InternalMongoError.incorrectReply(reply: response)
                }
                
                isMasterTest: if let doc = documents.first {
                    if doc["ismaster"] as Bool? == true {
                        debug("Found a master connection at \(host.host):\(host.port)")
                        host.isPrimary = true
                        guard let batchSize = doc["maxWriteBatchSize"] as Int32?, let minWireVersion = doc["minWireVersion"] as Int32?, let maxWireVersion = doc["maxWireVersion"] as Int32? else {
                            debug("No usable ismaster response found. Assuming defaults.")
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
                debug("Couldn't open a connection to MongoDB at \(host.host):\(host.port)")
                host.online = false
            }
            
            return host
        }
        
        reinitializeReplica = false
    }
    
    /// Sets up the `Server` to connect to the specified location.`Server`
    /// You need to provide a host as IP address or as a hostname recognized by the client's DNS.
    /// - parameter at: The hostname/IP address of the MongoDB server
    /// - parameter port: The port we'll connect on. Defaults to 27017
    /// - parameter authentication: The optional authentication details we'll use when connecting to the server
    /// - parameter automatically: Connect automatically
    ///
    /// - throws: When we can’t connect automatically, when the scheme/host is invalid and when we can’t connect automatically
    public init(hostname host: String, port: UInt16 = 27017, authenticatedAs authentication: (username: String, password: String, against: String)? = nil, usingTcpDriver tcpDriver: MongoTCP.Type? = nil, maxConnectionsPerServer maxConnections: Int = 10, ssl: Bool = false, defaultTimeout: TimeInterval = 30) throws {
        
        self.tcpType = tcpDriver ?? (ssl ? DefaultSSLTCPClient : DefaultTCPClient)
        self.servers = [(host: host, port: port, openConnections: 0, isPrimary: true, online: true)]
        self.maximumConnections = maxConnections
        self.authDetails = authentication
        self.defaultTimeout = defaultTimeout
        self.maximumConnectionsPerHost = maxConnections
        self.connectionPoolSemaphore = DispatchSemaphore(value: maxConnections)
        
        let authDB = self[authentication?.against ?? "admin"]
        
        let doc = try authDB.isMaster()
        
        guard let batchSize = doc["maxWriteBatchSize"] as Int32?, let minWireVersion = doc["minWireVersion"] as Int32?, let maxWireVersion = doc["maxWireVersion"] as Int32? else {
            debug("No usable ismaster response found. Assuming defaults.")
            serverData = (maxWriteBatchSize: 1000, maxWireVersion: 4, minWireVersion: 0, maxMessageSizeBytes: 48000000)
            return
        }
        
        var maxMessageSizeBytes = doc["maxMessageSizeBytes"] as Int32? ?? 0
        if maxMessageSizeBytes == 0 {
            maxMessageSizeBytes = 48000000
        }
        
        serverData = (maxWriteBatchSize: batchSize, maxWireVersion: maxWireVersion, minWireVersion: minWireVersion, maxMessageSizeBytes: maxMessageSizeBytes)
        
        self.connectionPoolMaintainanceQueue.async(execute: backgroundLoop)
    }
    
    private func makeConnection(writing: Bool = true, authenticatedFor: Database?) throws -> Connection {
        verbose("Attempting to create a new connection")
        self.hostPoolLock.lock()
        
        defer {
            self.hostPoolLock.unlock()
        }
        
        // Procedure to find best matching server
        
        // Takes a default server, which is the first primary server that is online
        guard var lowestOpenConnections = servers.first(where: { $0.isPrimary && $0.online }) else {
            verbose("No primary connection source has been found")
            throw MongoError.noServersAvailable
        }
        
        // If the connection has no need to be writable and slave reading is OK
        if !writing && slaveOK {
            // Find the next best match
            for server in servers.filter({ !$0.isPrimary && $0.online && $0.openConnections < maximumConnectionsPerHost }) {
                // If this match is any good
                if server.openConnections < lowestOpenConnections.openConnections || (lowestOpenConnections.isPrimary && lowestOpenConnections.openConnections < server.openConnections - 2) {
                    // Make it the new selected server
                    lowestOpenConnections = server
                }
            }
        }
        
        // The connections mustn't be over the maximum specified connection count
        if lowestOpenConnections.openConnections >= maximumConnectionsPerHost {
            verbose("Cannot create a new connection because the limit has been reached")
            throw MongoError.noServersAvailable
        }
        
        // Open a connection
        let connection = Connection(client: try tcpType.open(address: lowestOpenConnections.host, port: lowestOpenConnections.port), writable: lowestOpenConnections.isPrimary, host: (lowestOpenConnections.host, lowestOpenConnections.port), logger: self) {
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
            info("The found connection source is offline")
            throw MongoError.notConnected
        }
        
        // Add the count to both the global and server connection pool
        currentConnections += 1
        
        for (id, server) in servers.enumerated() where server == lowestOpenConnections {
            lowestOpenConnections.openConnections += 1
            servers[id] = lowestOpenConnections
            debug("Successfully created a new connection to the server at \(server.host):\(server.port)")
            return connection
        }
        
        // If the server couldn't be updated form some weird reason
        currentConnections -= 1
        fatal("Couldn't update the connection pool's metadata")
        throw MongoError.internalInconsistency
    }
    
    private func makeConnection(toHost host: (host: String, port: UInt16, openConnections: Int, isPrimary: Bool, online: Bool), authenticatedFor: Database?) throws -> Connection {
        verbose("Attempting to create a new connection to \(host.host):\(host.port)ss")
        
        // Make a connection to the specified host and add
        let connection = Connection(client: try tcpType.open(address: host.host, port: host.port), writable: host.isPrimary, host: (host.host, host.port), logger: self) {
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
            info("The found connection source is offline")
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
            debug("Successfully created a new connection to the server at \(server.host):\(server.port)")
            return connection
        }
        
        // If the server couldn't be updated form some weird reason
        fatal("Couldn't update the connection pool's metadata")
        
        currentConnections -= 1
        throw MongoError.internalInconsistency
    }
    
    internal func reserveConnection(writing: Bool = false, authenticatedFor db: Database?, toHost host: (String, UInt16)? = nil) throws -> Connection {
        verbose("Connection requested for database \(db)")
        
        var bestMatch: Server.Connection? = nil
        
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
                    
                    self.error("Disconnected from the replica set. Will attempt to reconnect")
                    
                    // If reinitializing is already happening, don't do it more than once
                    if !self.reinitializeReplica {
                        self.reinitializeReplica = true
                        self.maintainanceLoopCalls.append {
                            self.info("Attempting to reconnect to the replica set.")
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
        
        connectionPoolLock.unlock()
        
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
            self.connectionPoolLock.lock()
            guard currentConnections < maximumConnections && (!writing || servers.first(where: { $0.isPrimary })?.openConnections ?? maximumConnectionsPerHost < maximumConnectionsPerHost) else {
                let timeout = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 10_000_000_000)
                
                guard case .success = self.connectionPoolSemaphore.wait(timeout: timeout) else {
                    throw MongoError.timeout
                }
                
                return try reserveConnection(writing: writing, authenticatedFor: db, toHost: host)
            }
            
            // If we can create a new connection, create one
            let connection = try makeConnection(writing: writing, authenticatedFor: db)
            
            if let db = db {
                // On connection
                try connection.authenticate(toDatabase: db)
            }
            
            connections.append(connection)
            self.connectionPoolLock.unlock()
            connection.used = true
            
            return connection
        }
        
        // If the connection isn't already authenticated to this DB
        if let db = db, !connection.authenticatedDBs.contains(db.name) {
            // Authenticate
            info("Authenticating the connection to \(db)")
            try connection.authenticate(toDatabase: db)
        }
        
        connection.used = true
        
        return connection
    }
    
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
    
    private let connectionPoolMaintainanceQueue = DispatchQueue(label: "org.mongokitten.server.maintainanceQueue")
    
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
        
        return servers.contains(where: { $0.online && $0.isPrimary })
    }
    
    /// Disconnects from the MongoDB server
    ///
    /// - throws: Unable to disconnect
    public func disconnect() throws {
        connectionPoolLock.lock()
        isInitialized = false
        
        connections = []
        currentConnections = 0
        
        for (index, server) in servers.enumerated() {
            var server = server
            server.openConnections = 0
            servers[index] = server
        }
        
        connectionPoolLock.unlock()
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
            debug("Could not send data because of the following error: \"\(error)\"")
            connection.close()
        }

        guard semaphore.wait(timeout: DispatchTime.now() + timeout) == .success else {
            connection.incomingMutateLock.lock()
            connection.waitingForResponses[requestId] = nil
            connection.incomingMutateLock.unlock()
            debug("Waiting for request \(requestId) timed out")
            throw MongoError.timeout
        }
        
        guard let theReply = reply else {
            fatal("Reply was received but not found for id \(requestId)")
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
                error("Fetching databases list was not successful because a database name was missing")
                error(databaseInfos)
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
            
            let passHash = MD5.hash([UInt8]("\(user.user):mongo:\(user.password)".utf8)).hexString
            let key = MD5.hash([UInt8]("\(user.nonce)\(user.user)\(passHash))".utf8)).hexString
            command["key"] = key
        }

        let reply = try self["admin"].execute(command: command)
        let response = try firstDocument(in: reply)

        guard response["ok"] as Int? == 1 else {
            error("copydb was not successful because of the following error")
            error(response)
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
            error("clone was not successful because of the following error")
            error(response)
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
            error("shutdown was not successful because of the following error")
            error(response)
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
        
        let reply = try self[self.authDetails?.against ?? "admin"].execute(command: command, writing: true)
        let response = try firstDocument(in: reply)
        
        guard response["ok"] as Int? == 1 else {
            error("fsync was not successful because of the following error")
            error(response)
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
            error("usersInfo was not successful because of the following error")
            error(document)
            throw MongoError.commandFailure(error: document)
        }
        
        guard let users = document["users"] as Document? else {
            error("The user Document received from `usersInfo` could was not recognizable")
            error(document)
            throw MongoError.commandError(error: "No users found")
        }
        
        return users
    }
}

extension Server : CustomStringConvertible {
    /// A textual representation of this `Server`
    public var description: String {
        return "MongoKitten.Server<\(hostname)>"
    }
    
    /// This server's hostname
    internal var hostname: String {
        return "mongodb://" + servers.map { server in
            return "\(server.host):\(server.port)"
            }.joined(separator: ",")
    }
}

extension Server: Sequence {
    public func makeIterator() -> AnyIterator<Database> {
        guard var databases = try? self.getDatabases() else {
            return AnyIterator { nil }
        }
        
        return AnyIterator {
            return databases.count > 0 ? databases.removeFirst() : nil
        }
    }
}
