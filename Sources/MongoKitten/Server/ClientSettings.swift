//
//  ClientSettings.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 08/12/2016.
//
//

import Foundation
import TLS

/// The location of a Mongo server - i.e. server name and port number
public struct MongoHost: Equatable, ExpressibleByStringLiteral {

    /// host address
    public let hostname: String

    /// mongod port
    public let port: UInt16
    internal var openConnections = 0
    public internal(set) var online = false
    public internal(set) var isPrimary = false

    public init(hostname: String, port: UInt16 = 27017) {
        self.hostname = hostname
        self.port = port
    }
    
    public init(stringLiteral value: String) {
        let parts = value.characters.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        
        hostname = String(parts[0])
        port = parts.count == 2 ? UInt16(String(parts[1])) ?? 27017 : 27017
    }
    
    public init(unicodeScalarLiteral value: String) {
        let parts = value.characters.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        
        hostname = String(parts[0])
        port = parts.count == 2 ? UInt16(String(parts[1])) ?? 27017 : 27017
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        let parts = value.characters.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        
        hostname = String(parts[0])
        port = parts.count == 2 ? UInt16(String(parts[1])) ?? 27017 : 27017
    }
    
    public static func ==(lhs: MongoHost, rhs: MongoHost) -> Bool {
        return lhs.hostname == rhs.hostname && lhs.port == rhs.port
    }
}

/// Settings for connecting to MongoDB via SSL.
public struct SSLSettings: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.enabled = value
        self.invalidHostNameAllowed = false
        self.invalidCertificateAllowed = false
    }
    
    public var certificates: Certificates = .openbsd
    
    /// Enable SSL
    public let enabled: Bool

    /// Invalid host names should be allowed. Defaults to false. Take care before setting this to true, as it makes the application susceptible to man-in-the-middle attacks.
    public let invalidHostNameAllowed: Bool

    /// Invalis certificate should be allowed. Defaults to false. Take care before setting this to true, as it makes the application susceptible to man-in-the-middle attacks.
    public let invalidCertificateAllowed: Bool

    public init(enabled: Bool, invalidHostNameAllowed: Bool, invalidCertificateAllowed: Bool) {
        self.enabled = enabled
        self.invalidHostNameAllowed = invalidHostNameAllowed
        self.invalidCertificateAllowed = invalidCertificateAllowed
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
    case SCRAM_SHA_1
    case MONGODB_CR
    case MONGODB_X509
    case PLAIN
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

    public internal(set) var maxConnectionsPerServer: Int
    public let defaultTimeout: TimeInterval

    public init(hosts:[MongoHost], sslSettings: SSLSettings?,
                credentials: MongoCredentials?, maxConnectionsPerServer: Int = 10, defaultTimeout: TimeInterval = 30) {
        self.hosts = hosts
        self.sslSettings = sslSettings
        self.credentials = credentials
        self.maxConnectionsPerServer = maxConnectionsPerServer
        self.defaultTimeout = defaultTimeout
    }

    public init(host: MongoHost, sslSettings: SSLSettings?,
                credentials: MongoCredentials?, maxConnectionsPerServer: Int = 10, defaultTimeout: TimeInterval = 30) {
        self.hosts = [host]
        self.credentials = credentials
        self.sslSettings = sslSettings
        self.maxConnectionsPerServer = maxConnectionsPerServer
        self.defaultTimeout = defaultTimeout
    }
}

