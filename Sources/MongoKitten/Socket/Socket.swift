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


/// Socks is being made complient to MongoTCP
///
/// `close` is already defined in `Socks.TCPClient`
extension Socks.TCPClient : MongoTCP {
    /// Opens a socket to the given address at the given port with the given settings
    public static func open(address hostname: String, port: UInt16, options: [String: Any]) throws -> MongoTCP {
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
