//
//  ClientSettings.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 08/12/2016.
//
//

import Foundation


public struct MongoHost: Equatable, ExpressibleByStringLiteral {
    public let hostname: String
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

public struct SSLSettings: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.enabled = value
        self.invalidHostNameAllowed = false
        self.invalidCertificateAllowed = false
    }
    
    public let enabled: Bool
    public let invalidHostNameAllowed: Bool
    public let invalidCertificateAllowed: Bool

    public init(enabled: Bool, invalidHostNameAllowed: Bool, invalidCertificateAllowed: Bool) {
        self.enabled = enabled
        self.invalidHostNameAllowed = invalidHostNameAllowed
        self.invalidCertificateAllowed = invalidCertificateAllowed
    }
}

public enum AuthenticationMechanism {
    case SCRAM_SHA_1
    case MONGODB_CR
    case MONGODB_X509
    case PLAIN
}

public struct MongoCredentials {
    public let username: String
    public let password: String
    public let database: String?
    public let authenticationMechanism: AuthenticationMechanism

    public init(username: String, password: String, database: String? = nil, authenticationMechanism: AuthenticationMechanism = .SCRAM_SHA_1) {
        self.username = username
        self.password = password
        self.database = database
        self.authenticationMechanism = authenticationMechanism
    }

}

public struct ClientSettings {
    public internal(set) var hosts: [MongoHost]
    public let sslSettings: SSLSettings?
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

