//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

internal protocol BSONBytesProtocol {
    func makeBytes() -> [UInt8]
}

extension Int : BSONBytesProtocol {
    internal func makeBytes() -> [UInt8] {
        var integer = self.littleEndian
        return withUnsafePointer(to: &integer) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<Int>.size) {
                Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<Int>.size))
            }
        }
    }
}

extension Int64 : BSONBytesProtocol {
    internal func makeBytes() -> [UInt8] {
        let integer = self.littleEndian
        
        return [
            UInt8(integer & 0xFF),
            UInt8((integer >> 8) & 0xFF),
            UInt8((integer >> 16) & 0xFF),
            UInt8((integer >> 24) & 0xFF),
            UInt8((integer >> 32) & 0xFF),
            UInt8((integer >> 40) & 0xFF),
            UInt8((integer >> 48) & 0xFF),
            UInt8((integer >> 56) & 0xFF),
        ]
    }
}

extension Int32 : BSONBytesProtocol {
    internal func makeBytes() -> [UInt8] {
        let integer = self.littleEndian
        
        return [
            UInt8(integer & 0xFF),
            UInt8((integer >> 8) & 0xFF),
            UInt8((integer >> 16) & 0xFF),
            UInt8((integer >> 24) & 0xFF),
        ]
    }
}

extension Int16 : BSONBytesProtocol {
    internal func makeBytes() -> [UInt8] {
        let integer = self.littleEndian
        
        return [
            UInt8((integer >> 8) & 0xFF),
            UInt8(integer & 0xFF)
        ]
    }
}

extension Int8 : BSONBytesProtocol {
    internal func makeBytes() -> [UInt8] {
        return [UInt8(self)]
    }
}

extension UInt : BSONBytesProtocol {
    internal func makeBytes() -> [UInt8] {
        var integer = self.littleEndian
        return withUnsafePointer(to: &integer) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<UInt>.size) {
                Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<UInt>.size))
            }
        }
    }
}

extension UInt64 : BSONBytesProtocol {
    internal func makeBytes() -> [UInt8] {
        let integer = self.littleEndian
        
        return [
            UInt8(integer & 0xFF),
            UInt8((integer >> 8) & 0xFF),
            UInt8((integer >> 16) & 0xFF),
            UInt8((integer >> 24) & 0xFF),
            UInt8((integer >> 32) & 0xFF),
            UInt8((integer >> 40) & 0xFF),
            UInt8((integer >> 48) & 0xFF),
            UInt8((integer >> 56) & 0xFF),
        ]
    }
}

extension UInt32 : BSONBytesProtocol {
    internal func makeBytes() -> [UInt8] {
        let integer = self.littleEndian
        
        return [
            UInt8(integer & 0xFF),
            UInt8((integer >> 8) & 0xFF),
            UInt8((integer >> 16) & 0xFF),
            UInt8((integer >> 24) & 0xFF),
        ]
    }
}

extension UInt16 : BSONBytesProtocol {
    internal func makeBytes() -> [UInt8] {
        let integer = self.littleEndian
        
        return [
            UInt8(integer & 0xFF),
            UInt8((integer >> 8) & 0xFF)
        ]
    }
}

extension UInt8 : BSONBytesProtocol {
    internal func makeBytes() -> [UInt8] {
        return [self]
    }
}

extension Double : BSONBytesProtocol {
    internal func makeBytes() -> [UInt8] {
        var integer = self
        return withUnsafePointer(to: &integer) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<Double>.size) {
                Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<Double>.size))
            }
        }
    }
}
