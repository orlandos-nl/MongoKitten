//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Foundation

/// The location of a Mongo server - i.e. server name and port number
public struct MongoHost: Equatable, ExpressibleByStringLiteral {

    /// host address
    public let hostname: String

    /// mongod port
    public let port: UInt16
    
    /// The amount of currently open connection
    internal var openConnections = 0
    
    /// Os this host online
    public internal(set) var online = false
    
    /// Is this host a primary node
    public internal(set) var isPrimary = false

    /// Creates a new Host object that specifies the location of this mongod instance
    public init(hostname: String, port: UInt16 = 27017) {
        self.hostname = hostname
        self.port = port
    }
    
    /// Creates a new Host object from a string
    public init(stringLiteral value: String) {
        // Split the last ':', specifically for IPv6 addresses
        let parts = value.characters.reversed().split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        
        hostname = String(parts[parts.count == 2 ? 1 : 0].reversed())
        port = parts.count == 2 ? UInt16(String(parts[0].reversed())) ?? 27017 : 27017
    }
    
    /// Creates a new Host object from a string
    public init(unicodeScalarLiteral value: String) {
        // Split the last ':', specifically for IPv6 addresses
        let parts = value.characters.reversed().split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        
        hostname = String(parts[parts.count == 2 ? 1 : 0].reversed())
        port = parts.count == 2 ? UInt16(String(parts[0].reversed())) ?? 27017 : 27017
    }
    
    /// Creates a new Host object from a string
    public init(extendedGraphemeClusterLiteral value: String) {
        // Split the last ':', specifically for IPv6 addresses
        let parts = value.characters.reversed().split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        
        hostname = String(parts[parts.count == 2 ? 1 : 0].reversed())
        port = parts.count == 2 ? UInt16(String(parts[0].reversed())) ?? 27017 : 27017
    }
    
    /// Compares two hosts to be equal
    public static func ==(lhs: MongoHost, rhs: MongoHost) -> Bool {
        return lhs.hostname == rhs.hostname && lhs.port == rhs.port
    }
}

/// An enumeration of the MongodDB-supported authentication mechanisms.
///
/// - SCRAM_SHA_1: The SCRAM-SHA-1 mechanism.
/// - MONGODB_CR: The MongoDB Challenge Response mechanism.
/// - MONGODB_X509: The MongoDB X.509 mechanism.
/// - PLAIN: The PLAIN mechanism.
/// - GSSAPI: The GSSAPI mechanism. 
public enum AuthenticationMechanism: String {
    /// SCRAM-SHA-1 mechanism
    case SCRAM_SHA_1
    
    /// MongoDB Challenge-Response mechanism
    case MONGODB_CR
    
    /// X.509 certificate base authentication (currently unsupported)
    case MONGODB_X509
    
    /// PLAIN authentication (currently unsupported)
    case PLAIN
    
    /// GSSAPI authentication (currently unsupported)
    case GSSAPI
}

/// Represents credentials to authenticate to a mongo server,as well as the source of the credentials and the authentication mechanism to use.
public struct MongoCredentials {

    /// The Username
    public let username: String

    /// The Password
    public let password: String

    /// The database where the user is defined
    public let database: String?

    /// The Authentication Mechanism
    public let authenticationMechanism: AuthenticationMechanism

    /// Create a MongoCredential instance
    ///
    /// - Parameters:
    ///   - username: The user name
    ///   - password: The password
    ///   - database: The database where the user is defined
    ///   - authenticationMechanism: The authentication mechanism use to authenticated the user
    public init(username: String, password: String, database: String? = nil, authenticationMechanism: AuthenticationMechanism = .SCRAM_SHA_1) {
        self.username = username
        self.password = password
        self.database = database
        self.authenticationMechanism = authenticationMechanism
    }

}

/// Various settings to control the behavior of a MongoClient.
public struct ClientSettings {

    /// The Hosts to connect
    public internal(set) var hosts: [MongoHost]

    /// The SSL Settings
    public let sslSettings: SSLSettings?

    /// The credentials to authenticate to a mongo server
    public let credentials: MongoCredentials?

    /// Specified how many connections can be open per server
    public internal(set) var maxConnectionsPerServer: Int
    
    /// The default timeout for a request
    public let defaultTimeout: TimeInterval

    /// The application's identifier
    public let applicationName: String?

    /// Initializes the settings with a group of hosts, SSLsettings (if applicable) amonst other settings
    public init(hosts:[MongoHost], sslSettings: SSLSettings?, credentials: MongoCredentials?, maxConnectionsPerServer: Int = 100, defaultTimeout: TimeInterval = 30, applicationName: String? = nil) {

        self.hosts = hosts
        self.sslSettings = sslSettings
        self.credentials = credentials
        self.maxConnectionsPerServer = maxConnectionsPerServer
        self.defaultTimeout = defaultTimeout
        self.applicationName = applicationName
    }

    /// Initializes the settings with a single host, SSLsettings (if applicable) amonst other settings
    public init(host: MongoHost, sslSettings: SSLSettings?, credentials: MongoCredentials?, maxConnectionsPerServer: Int = 100, defaultTimeout: TimeInterval = 30, applicationName: String? = nil) {
        
        self.hosts = [host]
        self.credentials = credentials
        self.sslSettings = sslSettings
        self.maxConnectionsPerServer = maxConnectionsPerServer
        self.defaultTimeout = defaultTimeout
        self.applicationName = applicationName
    }
}

