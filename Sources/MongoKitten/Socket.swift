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

class TCPBuffer {
    var data: [UInt8] = []
}

public protocol MongoTCP : class {
    static func open(address hostname: String, port: UInt16) throws -> MongoTCP
    func close() throws
    func send(data binary: [UInt8]) throws
    func receive() throws -> [UInt8]
}

extension Socks.TCPClient : MongoTCP {
    public static func open(address hostname: String, port: UInt16) throws -> MongoTCP {
        let address = InternetAddress(hostname: hostname, port: port)
        return try TCPClient(address: address)
    }
    
    public func send(data binary: [UInt8]) throws {
        try self.send(bytes: binary)
    }
    
    public func receive() throws -> [UInt8] {
        return try self.receive(maxBytes: Int(UInt16.max))
    }
}
