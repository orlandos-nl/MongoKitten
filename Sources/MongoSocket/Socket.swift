//
//  Socket.swift
//  MongoKitten
//
//
//

import Foundation
import Socket
import SSLService

public final class MongoSocket: MongoTCP {

    private let socket: Socket

    private var sslEnabled = false

    public init(address hostname: String, port: UInt16, options: [String: Any]) throws {

        self.sslEnabled = options["sslEnabled"] as? Bool ?? false
        socket = try Socket.create() // tcp socket
        if sslEnabled {
            let invalidCertificateAllowed = options["invalidCertificateAllowed"] as? Bool ?? false
            let sslConfig = SSLService.Configuration(withCACertificateFilePath: nil, usingCertificateFile: nil, withKeyFile: nil, usingSelfSignedCerts: invalidCertificateAllowed, cipherSuite: nil)
            socket.delegate = try SSLService(usingConfiguration: sslConfig)
        }
        try socket.connect(to: hostname, port: Int32(port))
    }

    /// Sends the data to the other side of the connection
    public func send(data binary: [UInt8]) throws {
        try socket.write(from: UnsafeRawPointer(binary), bufSize: binary.count)
    }

    /// Receives any available data from the socket
    public func receive() throws -> [UInt8] {
        var myData = Data()
        _ = try socket.read(into: &myData)
        return [UInt8](myData)
    }

    /// `true` when connected, `false` otherwise
    public var isConnected: Bool {
        return socket.isConnected
    }

    /// Closes the connection
    public func close() throws {
        socket.close()
    }
}
