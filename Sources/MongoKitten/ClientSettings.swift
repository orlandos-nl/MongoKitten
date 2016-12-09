//
//  ClientSettings.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 08/12/2016.
//
//

import Foundation


public struct MongoHost {
    public let hostName: String
    public let port: UInt16

    public init(hostName: String, port: UInt16) {
        self.hostName = hostName
        self.port = port
    }
}

public struct SSLSettings {
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

public struct MongoCredential {
    public let username: String
    public let password: String
    public let database: String?
    public let authenticationMechanism: AuthenticationMechanism

    public init(username: String, password: String, database: String?, authenticationMechanism: AuthenticationMechanism) {
        self.username = username
        self.password = password
        self.database = database
        self.authenticationMechanism = authenticationMechanism
    }

}

public struct ClientSettings {
    public let hosts:[MongoHost]
    public let sslSettings: SSLSettings?
    public let credentials: MongoCredential?

    public let maxConnectionsPerServer: Int
    public let defaultTimeout: TimeInterval

    public init(hosts:[MongoHost], sslSettings: SSLSettings?,
                credentials: MongoCredential?, maxConnectionsPerServer: Int = 10, defaultTimeout: TimeInterval = 30) {
        self.hosts = hosts
        self.sslSettings = sslSettings
        self.credentials = credentials
        self.maxConnectionsPerServer = maxConnectionsPerServer
        self.defaultTimeout = defaultTimeout
    }

    public init(host:MongoHost) {

        self.hosts = [host]
        self.credentials = nil
        self.sslSettings = nil
        self.maxConnectionsPerServer = 10
        self.defaultTimeout = 30
    }

}

