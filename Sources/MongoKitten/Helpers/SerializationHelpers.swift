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
    func makeBytes() -> Bytes
}

extension Int : BSONBytesProtocol {
    internal func makeBytes() -> Bytes {
        var integer = self.littleEndian
        return withUnsafePointer(to: &integer) {
            $0.withMemoryRebound(to: Byte.self, capacity: MemoryLayout<Int>.size) {
                Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<Int>.size))
            }
        }
    }
}

extension Int64 : BSONBytesProtocol {
    internal func makeBytes() -> Bytes {
        let integer = self.littleEndian
        
        return [
            Byte(integer & 0xFF),
            Byte((integer >> 8) & 0xFF),
            Byte((integer >> 16) & 0xFF),
            Byte((integer >> 24) & 0xFF),
            Byte((integer >> 32) & 0xFF),
            Byte((integer >> 40) & 0xFF),
            Byte((integer >> 48) & 0xFF),
            Byte((integer >> 56) & 0xFF),
        ]
    }
}

extension Int32 : BSONBytesProtocol {
    internal func makeBytes() -> Bytes {
        let integer = self.littleEndian
        
        return [
            Byte(integer & 0xFF),
            Byte((integer >> 8) & 0xFF),
            Byte((integer >> 16) & 0xFF),
            Byte((integer >> 24) & 0xFF),
        ]
    }
}

extension Int16 : BSONBytesProtocol {
    internal func makeBytes() -> Bytes {
        let integer = self.littleEndian
        
        return [
            Byte((integer >> 8) & 0xFF),
            Byte(integer & 0xFF)
        ]
    }
}

extension Int8 : BSONBytesProtocol {
    internal func makeBytes() -> Bytes {
        return [Byte(self)]
    }
}

extension UInt : BSONBytesProtocol {
    internal func makeBytes() -> Bytes {
        var integer = self.littleEndian
        return withUnsafePointer(to: &integer) {
            $0.withMemoryRebound(to: Byte.self, capacity: MemoryLayout<UInt>.size) {
                Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<UInt>.size))
            }
        }
    }
}

extension UInt64 : BSONBytesProtocol {
    internal func makeBytes() -> Bytes {
        let integer = self.littleEndian
        
        return [
            Byte(integer & 0xFF),
            Byte((integer >> 8) & 0xFF),
            Byte((integer >> 16) & 0xFF),
            Byte((integer >> 24) & 0xFF),
            Byte((integer >> 32) & 0xFF),
            Byte((integer >> 40) & 0xFF),
            Byte((integer >> 48) & 0xFF),
            Byte((integer >> 56) & 0xFF),
        ]
    }
}

extension UInt32 : BSONBytesProtocol {
    internal func makeBytes() -> Bytes {
        let integer = self.littleEndian
        
        return [
            Byte(integer & 0xFF),
            Byte((integer >> 8) & 0xFF),
            Byte((integer >> 16) & 0xFF),
            Byte((integer >> 24) & 0xFF),
        ]
    }
}

extension UInt16 : BSONBytesProtocol {
    internal func makeBytes() -> Bytes {
        let integer = self.littleEndian
        
        return [
            Byte(integer & 0xFF),
            Byte((integer >> 8) & 0xFF)
        ]
    }
}

extension Byte : BSONBytesProtocol {
    internal func makeBytes() -> Bytes {
        return [self]
    }
}

extension Double : BSONBytesProtocol {
    internal func makeBytes() -> Bytes {
        var integer = self
        return withUnsafePointer(to: &integer) {
            $0.withMemoryRebound(to: Byte.self, capacity: MemoryLayout<Double>.size) {
                Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<Double>.size))
            }
        }
    }
}
