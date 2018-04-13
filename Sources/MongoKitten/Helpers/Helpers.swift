//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import BSON
import Foundation

enum Commands {}
public enum Reply {}

public enum Errors {}

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

extension BSONDecoder {
    static func decodeOrError<T: Decodable>(_ type: T.Type, from doc: Document) throws -> T {
        do {
            return try BSONDecoder().decode(T.self, from: doc)
        } catch {
            let error = (try? BSONDecoder().decode(MongoServerError.self, from: doc)) ?? error
            
            throw error
        }
    }
}

struct MongoServerError: Error, Decodable {
    var ok: Bool
    var errmsg: String
    var code: Int
    var codeName: String
    
    var localizedDescription: String {
        return """
        message: \(errmsg)
        code: \(code)
        codeName: \(codeName)
        """
    }
}

extension Swift.Collection where Iterator.Element == UInt8 {
    public var hexString: String {
        var data = Data()
        data.reserveCapacity(24)
        
        for byte in self {
            data.append(radix16table[Int(byte / 16)])
            data.append(radix16table[Int(byte % 16)])
        }
        
        return String(data: data, encoding: .utf8)!
    }
}

fileprivate let radix16table: [UInt8] = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66]
