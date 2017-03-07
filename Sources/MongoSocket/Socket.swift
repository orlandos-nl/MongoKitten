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

    private var data: Data = Data(capacity: 2048)

    public init(address hostname: String, port: UInt16, options: [String: Any]) throws {

        self.sslEnabled = options["sslEnabled"] as? Bool ?? false
        socket = try Socket.create() // tcp socket
        if sslEnabled {
            let invalidCertificateAllowed = options["invalidCertificateAllowed"] as? Bool ?? false
            var sslConfig = SSLService.Configuration(withCipherSuite: nil)
            if let sslCAFile = options["sslCAFile"] as? String {
                #if os(Linux)
                    if let cert = try? String(contentsOfFile: sslCAFile,encoding: .utf8) {
                        let trimmedCert = cert.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        sslConfig = SSLService.Configuration(withPEMCertificateString: trimmedCert)
                    }
                #endif
            }
            socket.delegate = try SSLService(usingConfiguration: sslConfig)
        }
        try socket.connect(to: hostname, port: Int32(port))
    }

    /// Sends the data to the other side of the connection
    public func send(data binary: [UInt8]) throws {
        try socket.write(from: UnsafeRawPointer(binary), bufSize: binary.count)
    }

    /// Receives any available data from the socket
    public func receive(into buffer: inout [UInt8]) throws {
        self.data.count = 0
        buffer.removeAll()
        _ = try socket.read(into: &self.data)
        buffer.append(contentsOf: self.data)
    }
    
    /// Receives all available data from the socket
    public func  receive(into data: inout Data) throws {
        _ = try socket.read(into: &data)
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
