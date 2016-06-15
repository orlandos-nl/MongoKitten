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

enum TCPError : ErrorProtocol {
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

final class CSocket : MongoTCP {
    private var sock: Int32 = -1
    
    static func open(address hostname: String, port: UInt16) throws -> MongoTCP {
        let s = CSocket()
        
        #if os(Linux)
            s.sock = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
            s.sock = socket(AF_INET, SOCK_STREAM, 0)
        #endif
        if s.sock < 0 {
            throw TCPError.ConnectionFailed
        }
        
        var server = sockaddr_in()
        
        let pointer = gethostbyname(hostname)
        
        if pointer != nil {
            #if !swift(>=3.0)
                let hostInfo = pointer.pointee
            #else
                let hostInfo = pointer!.pointee
            #endif
            
            server.sin_addr = UnsafeMutablePointer<UnsafeMutablePointer<in_addr>>(hostInfo.h_addr_list)[0].pointee
        } else {
            server.sin_addr.s_addr = UInt32(inet_addr(hostname))
        }
        
        #if os(Linux)
            server.sin_family = UInt16(AF_INET)
        #else
            server.sin_family = UInt8(AF_INET)
        #endif
        server.sin_port = port.bigEndian
        
        try withUnsafePointer(&server) {
            if connect(s.sock, UnsafePointer<sockaddr>($0), UInt32(sizeof(server.dynamicType))) < 0 {
                throw TCPError.ConnectionFailed
            }
        }
        
        return s
    }
    
    @warn_unqualified_access
    func close() throws {
        #if os(Linux)
            let _ = Glibc.close(sock)
        #else
            let _ = Darwin.close(sock)
        #endif
    }
    
    func send(data binary: [UInt8]) throws {
        #if os(Linux)
            let code = Glibc.send(sock, binary, binary.count, 0)
        #else
            let code = Darwin.send(sock, binary, binary.count, 0)
        #endif
        if code < 0 {
            throw TCPError.SendFailure(errorCode: code)
        }
    }
    
    func receive() throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: 2048)
        let receivedBytes = recv(sock, &buffer, buffer.count, 0)
        
        guard receivedBytes >= 0 else {
            throw TCPError.ReceiveFailure(errorCode: receivedBytes)
        }
        
        guard receivedBytes != 0 else {
            // The connection has been closed
            _ = try? self.close()
            throw TCPError.ConnectionClosedByServer
        }
        
        // Strip the zeroes
        buffer.removeSubrange(receivedBytes..<buffer.count)
        
        return buffer
    }
}
