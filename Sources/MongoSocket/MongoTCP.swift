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

public enum MongoSocketError:Error {
    case clientNotInitialized
}

public final class Buffer {
    public let pointer: UnsafeMutablePointer<UInt8>
    public let capacity: Int
    public var usedCapacity: Int = 0
    
    public init(capacity: Int = 65_507) {
        pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        self.capacity = capacity
    }
    
    deinit {
        free(pointer)
    }
}

public typealias ReadCallback = ((UnsafeMutablePointer<UInt8>, Int)->())
public typealias ErrorCallback = ((Error)->())

/// A class buffer that stores all received bytes without Copy-on-Write for efficiency
public class TCPBuffer {
    /// The buffer data
    public var data: [UInt8] = []
    
    public init() { }
}

/// Any socket conforming to this protocol can be used to connect to a server.
public protocol MongoTCP : class {
    
    /// Opens a socket to the given address at the given port with the given settings
    init(address hostname: String, port: UInt16, options: [String: Any], onRead: @escaping ReadCallback, onError: @escaping ErrorCallback) throws
    
    /// Closes the connection
    func close() throws
    
    /// Sends the data to the other side of the connection
    func send(data pointer: UnsafePointer<UInt8>, withLengthOf length: Int) throws
    
    /// `true` when connected, `false` otherwise
    var isConnected: Bool { get }
}
