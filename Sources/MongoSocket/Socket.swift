//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Foundation
import Sockets
import libc
import Dispatch

#if os(iOS) || os(macOS)
import Security
import Darwin
#else
import CTLS
import TLS
import Glibc
#endif

public final class MongoSocket: MongoTCP {
    public private(set) var plainClient: Int32
    
    #if os(iOS) || os(macOS)
    private let sslClient: (SSLContext, Int32)?
    #else
    private let sslClient: ClientSocket?
    #endif
    
    private var sslEnabled = false
    
    private static let socketQueue = DispatchQueue(label: "org.mongokitten.socketQueue", qos: DispatchQoS.userInteractive)
    
    public var onRead: ReadCallback
    public var onError: ErrorCallback
    
    private var operations = [(UnsafePointer<UInt8>, Int)]()
    private let operationLock = NSLock()
    
    private let readSource: DispatchSourceRead
    private let writeSource: DispatchSourceWrite

    public init(address hostname: String, port: UInt16, options: [String: Any], onRead: @escaping ReadCallback, onError: @escaping ErrorCallback) throws {
        self.sslEnabled = options["sslEnabled"] as? Bool ?? false
        self.onRead = onRead
        self.onError = onError
        
        var criteria = addrinfo.init()
        
        let hostname = hostname == "localhost" ? "127.0.0.1" : hostname
        
        #if os(macOS) || os(iOS)
        criteria.ai_socktype = Int32(SOCK_STREAM)
        #else
        criteria.ai_socktype = SOCK_STREAM
        #endif
        
        criteria.ai_family = Int32(AF_UNSPEC)
        criteria.ai_flags = AI_PASSIVE
        criteria.ai_protocol = Int32(IPPROTO_TCP)
        
        var serverinfo: UnsafeMutablePointer<addrinfo>? = nil
        let ret = getaddrinfo(hostname, port.description, &criteria, &serverinfo)
        
        guard let addrList = serverinfo else { throw Error.ipAddressResolutionFailed }
        defer { freeaddrinfo(addrList) }
        
        guard let addrInfo = addrList.pointee.ai_addr else { throw Error.ipAddressResolutionFailed }
        
        let ptr = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
        ptr.initialize(to: sockaddr_storage())
        
        switch Int32(addrInfo.pointee.sa_family) {
        case Int32(AF_INET):
            let addr = UnsafeMutablePointer<sockaddr_in>.init(OpaquePointer(addrInfo))!
            let specPtr = UnsafeMutablePointer<sockaddr_in>(OpaquePointer(ptr))
            specPtr.assign(from: addr, count: 1)
        case Int32(AF_INET6):
            let addr = UnsafeMutablePointer<sockaddr_in6>(OpaquePointer(addrInfo))!
            let specPtr = UnsafeMutablePointer<sockaddr_in6>(OpaquePointer(ptr))
            specPtr.assign(from: addr, count: 1)
        default:
            throw Error.ipAddressResolutionFailed
        }
        
        #if os(macOS) || os(iOS)
            self.plainClient = socket(Int32(addrInfo.pointee.sa_family), SOCK_STREAM, Int32(IPPROTO_TCP))
        #else
            self.plainClient = socket(Int32(addrInfo.pointee.sa_family), Int32(SOCK_STREAM.rawValue), Int32(IPPROTO_TCP))
        #endif
        
        signal(SIGPIPE, SIG_IGN)
        
        guard plainClient >= 0 else {
            throw Error.cannotConnect
        }
        
        if Int32(addrInfo.pointee.sa_family) == Int32(AF_INET) {
            connect(self.plainClient, UnsafeMutablePointer<sockaddr>(OpaquePointer(ptr)), socklen_t(MemoryLayout<sockaddr_in>.size))
        } else {
            connect(self.plainClient, UnsafeMutablePointer<sockaddr>(OpaquePointer(ptr)), socklen_t(MemoryLayout<sockaddr_in6>.size))
        }
        
        
        #if os(macOS) || os(iOS)
            var val = 1
            setsockopt(self.plainClient, SOL_SOCKET, SO_NOSIGPIPE, &val, socklen_t(MemoryLayout<Int>.stride))
            
            if sslEnabled {
                guard let context = SSLCreateContext(nil, .clientSide, .streamType) else {
                    throw Error.cannotCreateContext
                }
                
                SSLSetIOFuncs(context, { context, data, length in
                    let context = context.bindMemory(to: Int32.self, capacity: 1).pointee
                    var read = Darwin.recv(context, data, length.pointee, 0)
                    
                    length.assign(from: &read, count: 1)
                    return 0
                }, { context, data, length in
                    let context = context.bindMemory(to: Int32.self, capacity: 1).pointee
                    var written = Darwin.send(context, data, length.pointee, 0)
                    
                    length.assign(from: &written, count: 1)
                    return 0
                })
                
                SSLSetConnection(context, &self.plainClient)
                
                if let path = options["CAFile"] as? String, let data = FileManager.default.contents(atPath: path) {
                    let bytes = [UInt8](data)
                    
                    if let certBytes = CFDataCreate(kCFAllocatorDefault, bytes, data.count), let cert = SecCertificateCreateWithData(kCFAllocatorDefault, certBytes) {
                        SSLSetCertificateAuthorities(context, cert, true)
                    }
                }
                
                let status = SSLHandshake(context)
                
                self.sslClient = (context, self.plainClient)
            } else {
                self.sslClient = nil
            }
        #else
        if sslEnabled {
            plainClient = nil
            
            let address = hostname.lowercased() == "localhost" ? InternetAddress.localhost(port: port) : InternetAddress.init(hostname: hostname, port: port)

            let internetSocket = try TCPInternetSocket(address, scheme: "mongodb")
            
            let verifyCertificate = !(options["invalidCertificateAllowed"] as? Bool ?? false)
            let verifyHost = !(options["invalidHostNameAllowed"] as? Bool ?? false)
            
            let context: TLS.Context
            
            if let CAFile = options["CAFile"] as? String {
                context = try TLS.Context(.client, .certificateAuthority(signature: .signedFile(caCertificateFile: CAFile)), verifyHost: verifyHost, verifyCertificates: verifyCertificate)
            } else {
                context = try TLS.Context(.client, verifyHost: verifyHost, verifyCertificates: verifyCertificate)
            }
            
            sslClient = TLS.InternetSocket(internetSocket, context)
            try sslClient!.connect(servername: hostname)
            
            self.plainClient = sslClient!.socket.descriptor.raw
        } else {
            sslClient = nil
            let address = hostname.lowercased() == "localhost" ? InternetAddress.localhost(port: port) : InternetAddress(hostname: hostname, port: port)
            plainClient = try TCPInternetSocket(address, scheme: "mongodb")
            try plainClient?.connect()
        }
        #endif
        
        self.readSource = DispatchSource.makeReadSource(fileDescriptor: self.plainClient, queue: MongoSocket.socketQueue)
        self.writeSource = DispatchSource.makeWriteSource(fileDescriptor: self.plainClient, queue: MongoSocket.socketQueue)
        
        let incomingBuffer = Buffer()
        
        self.readSource.setEventHandler(qos: .userInteractive) {
            do {
                var read = 0
                
                if self.sslEnabled {
                    #if os(macOS) || os(iOS)
                        SSLRead(self.sslClient!.0, incomingBuffer.pointer, Int(UInt16.max), &read)
                    #else
                        read = Int(SSL_read(sslClient.cSSL, buffer.pointer, Int32(UInt16.max)))
                    #endif
                } else {
                    read = Darwin.recv(self.plainClient, incomingBuffer.pointer, Int(UInt16.max), 0)
                }
                
                incomingBuffer.usedCapacity = read
                
                guard read > -1 else {
                    throw Error.cannotRead
                }
                
                self.onRead(incomingBuffer.pointer, incomingBuffer.usedCapacity)
            } catch {
                self.onError(error)
            }
        }
        
        self.writeSource.setEventHandler(qos: .userInteractive) {
            do {
                self.operationLock.lock()
                defer { self.operationLock.unlock() }
                
                guard self.operations.count > 0 else {
                    return
                }
                
                let (pointer, length) = self.operations.removeFirst()
                
                let binary = Array(UnsafeBufferPointer<Byte>(start: pointer, count: length))
                
                if self.sslEnabled {
                    #if os(macOS) || os(iOS)
                        var ditched = binary.count
                        SSLWrite(self.sslClient!.0, binary, binary.count, &ditched)
                        
                        guard ditched == binary.count else {
                            throw Error.cannotSendData
                        }
                    #else
                        try self.plainClient!.write(binary, flushing: true)
                    #endif
                } else {
                    guard Darwin.send(self.plainClient, binary, binary.count, 0) == binary.count else {
                        throw Error.cannotSendData
                    }
                }
            } catch {
                self.onError(error)
            }
        }
        
        self.readSource.resume()
        self.writeSource.resume()
    }
    
    enum Error : Swift.Error {
        case disconnectedByPeer
        case cannotSendData
        case cannotCreateContext
        case cannotRead
        case cannotConnect
        case ipAddressResolutionFailed
    }

    /// Sends the data to the other side of the connection
    public func send(data pointer: UnsafePointer<UInt8>, withLengthOf length: Int) {
        self.operationLock.lock()
        defer { self.operationLock.unlock() }
        
        self.operations.append((pointer, length))
    }
    
    /// Closes the connection
    public func close() throws {
        if sslEnabled {
            #if os(macOS) || os(iOS)
                _ = Darwin.close(sslClient!.1)
            #else
                try sslClient.close()
            #endif
        } else {
            _ = Darwin.close(plainClient)
        }
    }
    
    public var isConnected: Bool {
        return true
    }
}
