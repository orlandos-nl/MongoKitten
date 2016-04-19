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

public protocol MongoTCP : AnyObject {
    static func open(address: String, port: UInt16) throws -> Self
    func close() throws
    func send(data: [UInt8]) throws
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

final class CSocket : MongoTCP {
    private var sock: Int32 = -1
    
    static func open(address: String, port: UInt16) throws -> CSocket {
        let s = CSocket()
        
        s.sock = socket(AF_INET, Int32(SOCK_STREAM), 0)
        if s.sock < 0 {
            throw TCPError.ConnectionFailed
        }
        
        var server = sockaddr_in()
        
        if let pointer = gethostbyname(address) {
            let hostInfo = pointer.pointee
            
            server.sin_addr = UnsafeMutablePointer<UnsafeMutablePointer<in_addr>>(hostInfo.h_addr_list)[0].pointee
        } else {
            server.sin_addr.s_addr = UInt32(inet_addr(address))
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
    
    func close() throws {
        #if os(Linux)
            Glibc.close(sock)
        #else
            Darwin.close(sock)
        #endif
    }
    
    func send(data: [UInt8]) throws {
        #if os(Linux)
            let code = Glibc.send(sock, data, data.count, 0)
        #else
            let code = Darwin.send(sock, data, data.count, 0)
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