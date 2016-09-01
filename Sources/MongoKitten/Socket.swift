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

public protocol MongoTCP : class {
    static func open(address hostname: String, port: UInt16) throws -> MongoTCP
    func close() throws
    func send(data binary: [UInt8]) throws
    func receive() throws -> [UInt8]
}

enum TCPError : Error {
    case ConnectionFailed
    case NotConnected
    case AlreadyConnected
    case SendFailure(errorCode: Int)
    case ReceiveFailure(errorCode: Int)
    case ConnectionClosedByServer
    case ConnectionClosed
    case BindFailed
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
        return try self.receiveAll()
    }
}

