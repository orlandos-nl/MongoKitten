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

enum Commands {}
public enum Reply {}

public enum Errors {}

extension Data {
    /// Transforms
    public var hexString: String {
        var bytes = Data()
        bytes.reserveCapacity(self.count * 2)
        
        for byte in self {
            bytes.append(radix16table[Int(byte / 16)])
            bytes.append(radix16table[Int(byte % 16)])
        }
        
        return String(bytes: bytes, encoding: .utf8)!
    }
}

fileprivate let radix16table: [UInt8] = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66]

extension Errors {
    public struct Write: Codable, Error {
        public var index: Int
        public var code: Int
        public var errmsg: String // TODO: errorMessage?
    }
    
    public struct WriteConcern: Codable, Error {
        public var code: Int
        public var errmsg: String // TODO: errorMessage?
    }
}

public protocol DocumentCodable: Codable {
    init(from document: Document)
    
    var document: Document { get }
}

public func +<T: DocumentCodable>(lhs: T, rhs: T) -> T {
    return T(from: lhs.document + rhs.document)
}

extension DocumentCodable {
    public func encode(to encoder: Encoder) throws {
        try self.document.encode(to: encoder)
    }

    public init(from decoder: Decoder) throws {
        self.init(from: try Document(from: decoder))
    }
}
