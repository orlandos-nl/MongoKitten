//
//  MongoTCP.swift
//  MongoKitten
//
//
//

import Foundation

public enum MongoSocketError:Error {
    case clientNotInitialized
}

/// A class buffer that stores all received bytes without Copy-on-Write for efficiency
public class TCPBuffer {
    /// The buffer data
    public var data: [UInt8] = []

    public init() { }
}

/// Any socket conforming to this protocol can be used to connect to a server.
public protocol MongoTCP : class {

    /// Opens a socket to the given address at the given port with the given settings
    init(address hostname: String, port: UInt16, options: [String: Any]) throws

    /// Closes the connection
    func close() throws

    /// Sends the data to the other side of the connection
    func send(data binary: [UInt8]) throws

    /// Receives any available data from the socket
    func receive(into buffer: inout [UInt8]) throws

    /// `true` when connected, `false` otherwise
    var isConnected: Bool { get }
}
