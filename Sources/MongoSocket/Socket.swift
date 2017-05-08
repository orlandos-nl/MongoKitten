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
import CTLS
import Dispatch
import TLS

public final class MongoSocket: MongoTCP {
    private let plainClient: TCPInternetSocket?
    private let sslClient: ClientSocket?
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
            
            self.readSource = DispatchSource.makeReadSource(fileDescriptor: sslClient!.socket.descriptor.raw, queue: MongoSocket.socketQueue)
            self.writeSource = DispatchSource.makeWriteSource(fileDescriptor: sslClient!.socket.descriptor.raw, queue: MongoSocket.socketQueue)
        } else {
            sslClient = nil
            let address = hostname.lowercased() == "localhost" ? InternetAddress.localhost(port: port) : InternetAddress(hostname: hostname, port: port)
            plainClient = try TCPInternetSocket(address, scheme: "mongodb")
            try plainClient?.connect()
            
            self.readSource = DispatchSource.makeReadSource(fileDescriptor: plainClient!.descriptor.raw, queue: MongoSocket.socketQueue)
            self.writeSource = DispatchSource.makeWriteSource(fileDescriptor: plainClient!.descriptor.raw, queue: MongoSocket.socketQueue)
        }
        
        let incomingBuffer = Buffer()
        
        self.readSource.setEventHandler(qos: .userInteractive) {
            do {
                try self.receive(into: incomingBuffer)
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
                    _ = try self.sslClient!.write(binary)
                } else {
                    _ = try self.plainClient!.write(binary)
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
    }

    /// Sends the data to the other side of the connection
    public func send(data pointer: UnsafePointer<UInt8>, withLengthOf length: Int) {
        self.operationLock.lock()
        defer { self.operationLock.unlock() }
        
        self.operations.append((pointer, length))
    }

    /// Receives any available data from the socket
    private func receive(into buffer: Buffer) throws {
        let receivedBytes: Int
        
        if sslEnabled {
            guard let sslClient = sslClient else { throw MongoSocketError.clientNotInitialized }
            
            receivedBytes = Int(SSL_read(sslClient.cSSL, buffer.pointer, Int32(UInt16.max)))
        } else {
            guard let plainClient = plainClient else { throw MongoSocketError.clientNotInitialized }
            
            receivedBytes = libc.recv(plainClient.descriptor.raw, buffer.pointer, Int(UInt16.max), 0)
        }
        
        guard receivedBytes != -1 else {
            if errno == ECONNRESET {
                // closed by peer, need to close this side.
                // Since this is not an error, no need to throw unless the close
                // itself throws an error.
                _ = try self.close()
                return
            } else {
                throw Error.disconnectedByPeer
            }
        }
        
        buffer.usedCapacity = receivedBytes
    }
    
    /// `true` when connected, `false` otherwise
    public var isConnected: Bool {
        if sslEnabled {
            return !(sslClient?.socket.isClosed ?? false)
        } else {
            return !(plainClient?.isClosed ?? false)
        }
    }
    
    /// Closes the connection
    public func close() throws {
        if sslEnabled {
            guard let sslClient = sslClient else { throw MongoSocketError.clientNotInitialized }
            try sslClient.close()
        } else {
            guard let plainClient = plainClient else { throw MongoSocketError.clientNotInitialized }
            try plainClient.close()
        }
    }
}
