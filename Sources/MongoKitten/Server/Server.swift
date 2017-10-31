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

import Async
import Foundation
import Dispatch

/// A ResponseHandler is a closure that receives a MongoReply to process it
/// It's internal because ReplyMessages are an internal struct that is used for direct communication with MongoDB only
internal typealias ResponseHandler = ((Message) -> Void)

/// A server object is the core of MongoKitten as it's used to communicate to the server.
/// You can select a `Database` by subscripting an instance of this Server with a `String`.
public final class Server {
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
    internal var cachedLoginData: (password: Data, clientKey: Data, serverKey: Data)? = nil
    
    /// Handles errors within cursors
    public var cursorErrorHandler: ((Error)->()) = { doc in
        print(doc)
    }
    
    public let connectionPool: ConnectionPool
    
    /// The ClientSettings used to connect to server(s)
    internal var clientSettings: ClientSettings
    
    /// The next Request we sent starting at 0
    internal var nextRequestID: Int32 = 0
    
    /// `MongoTCP` Socket bound to the MongoDB Server
    private var connections = [DatabaseConnection]()
    
    /// Whether to verify the remote host or not, that is the question
    internal var sslVerify = true
    
    /// The server's details like the wire protocol version
    internal private(set) var serverData: (maxWriteBatchSize: Int32, maxWireVersion: Int32, minWireVersion: Int32, maxMessageSizeBytes: Int32)?
    
    /// The server's BuildInfo
    ///
    /// Do not access from the initialization process!
    public private(set) var buildInfo: BuildInfo?
    
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
        
        if clientSettings.hosts.count > 1 {
            self.isReplica = true
            try initializeReplica()
        } else {
            guard clientSettings.hosts.count == 1 else {
                throw MongoError.noServersAvailable
            }
            
            self.clientSettings.hosts[0].isPrimary = true
            self.clientSettings.hosts[0].online = true
            
            let connection = try makeConnection(toHost: self.clientSettings.hosts[0], authenticatedFor: nil)
            connection.users += 1
            
            defer {
                returnConnection(connection)
            }
            
            connections.append(connection)
            
            let authDB = self[self.clientSettings.credentials?.database ?? "admin"]
            var document: Document = [
                "isMaster": Int32(1)
            ]
            
            document.append(self.driverInformation, forKey: "client")
            
            let commandMessage = Message.Query(requestID: self.nextMessageID(), flags: [], collection: "\(authDB.name).$cmd", numbersToSkip: 0, numbersToReturn: 1, query: document, returnFields: nil)
            let response = try self.sendAsync(message: commandMessage, overConnection: connection).await()
            
            var maxMessageSizeBytes = Int32(response.documents.first?["maxMessageSizeBytes"]) ?? 0
            if maxMessageSizeBytes == 0 {
                maxMessageSizeBytes = 48000000
            }
            
            self.serverData = (maxWriteBatchSize: Int32(response.documents.first?["maxWriteBatchSize"]) ?? 1000, maxWireVersion: Int32(response.documents.first?["maxWireVersion"]) ?? 4, minWireVersion: Int32(response.documents.first?["minWireVersion"]) ?? 0, maxMessageSizeBytes: maxMessageSizeBytes)
        }
        
//        self.buildInfo = try getBuildInfo()
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
    convenience public init(_ url: String, maxConnectionsPerServer maxConnections: Int = 100, defaultTimeout: TimeInterval = 30) throws {
        let clientSettings = try ClientSettings(url)
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
        
        let db = Database(named: databaseName, atServer: self, connectionPool: connectionPool)
        
        databaseCache[databaseName] = Weak(db)
        return db
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
