//
//  Socket.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 18-04-16.
//
//

//import Foundation

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Socks

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

/// Socks is being made complient to MongoTCP
///
/// `close` is already defined in `Socks.TCPClient`
extension Socks.TCPClient : MongoTCP {
    /// Opens a socket to the given address at the given port with the given settings
    public static func open(address hostname: String, port: UInt16, options: ClientSettings) throws -> MongoTCP {
        let address = hostname.lowercased() == "localhost" ? InternetAddress.localhost(port: port) : InternetAddress(hostname: hostname, port: port)
        return try TCPClient(address: address)
    }
    
    /// Sends the data to the other side of the connection
    public func send(data binary: [UInt8]) throws {
        try self.send(bytes: binary)
    }
    
    /// Receives any available data from the socket
    public func receive() throws -> [UInt8] {
        return try self.receive(maxBytes: Int(UInt16.max))
    }
    
    /// `true` when connected, `false` otherwise
    public var isConnected: Bool {
        return !socket.closed
    }
}
