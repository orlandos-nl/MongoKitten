//
//  Socket.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 18-04-16.
//
//

import Foundation
import Socks
import SocksCore
import TLS

public final class MongoSocket: MongoTCP {

    private let plainClient: Socks.TCPClient?
    private let sslClient: TLS.Socket?
    private var sslEnabled = false

    public init(address hostname: String, port: UInt16, options: [String: Any]) throws {

        self.sslEnabled = options["sslEnabled"] as? Bool ?? false

        if sslEnabled {
            plainClient = nil
            let address = hostname.lowercased() == "localhost" ? InternetAddress.localhost(port: port) : InternetAddress.init(hostname: hostname, port: port)

            let internetSocket = try TCPInternetSocket(address: address)
            let invalidCertificateAllowed = options["invalidCertificateAllowed"] as? Bool ?? false
            let invalidHostNameAllowed = options["invalidHostNameAllowed"] as? Bool ?? false
            let config = try TLS.Config(mode: .client, certificates: .openbsd, verifyHost: !invalidHostNameAllowed, verifyCertificates: !invalidCertificateAllowed)

            sslClient = try TLS.Socket(config: config, socket: internetSocket)
            try sslClient?.connect(servername: hostname)
        } else {
            sslClient = nil
            let address = hostname.lowercased() == "localhost" ? InternetAddress.localhost(port: port) : InternetAddress(hostname: hostname, port: port)
            plainClient = try TCPClient(address: address)
        }
    }

    /// Sends the data to the other side of the connection
    public func send(data binary: [UInt8]) throws {
        if sslEnabled {
            try sslClient?.send(binary)
        } else {
            try plainClient?.send(bytes: binary)
        }
    }

    /// Receives any available data from the socket
    public func receive() throws -> [UInt8] {
        if sslEnabled {
            guard let sslClient = sslClient else { throw MongoSocketError.clientNotInitialized }
            return try sslClient.receive(max: Int(UInt16.max))
        } else {
            guard let plainClient = plainClient else { throw MongoSocketError.clientNotInitialized }
            return try plainClient.receive(maxBytes: Int(UInt16.max))
        }
    }

    /// `true` when connected, `false` otherwise
    public var isConnected: Bool {
        if sslEnabled {
            return !(sslClient?.socket.closed ?? false)
        } else {
            return !(plainClient?.socket.closed ?? false)
        }
    }

    /// Closes the connection
    public func close() throws {
        if sslEnabled {
            guard let sslClient = sslClient else { throw MongoSocketError.clientNotInitialized }
            try sslClient.close()
        } else {
            guard let plainClient = plainClient else { throw MongoSocketError.clientNotInitialized }
            try plainClient.close()
        }
    }
}
