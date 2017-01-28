//
//  MongoTCP.swift
//  MongoKitten
//
//
//

import Foundation

/// A class buffer that stores all received bytes without Copy-on-Write for efficiency
class TCPBuffer {
    /// The buffer data
    var data: [UInt8] = []
}

/// Any socket conforming to this protocol can be used to connect to a server.
public protocol MongoTCP : class {
    /// Opens a socket to the given address at the given port with the given settings
    static func open(address hostname: String, port: UInt16, options: ClientSettings) throws -> MongoTCP

    /// Closes the connection
    func close() throws

    /// Sends the data to the other side of the connection
    func send(data binary: [UInt8]) throws

    /// Receives any available data from the socket
    func receive() throws -> [UInt8]

    /// `true` when connected, `false` otherwise
    var isConnected: Bool { get }
}
