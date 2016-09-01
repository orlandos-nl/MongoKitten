//
//  IntExtension.swift
//  CryptoSwift
//
//  Created by Marcin Krzyzanowski on 12/08/14.
//  Copyright (C) 2014 Marcin Krzyżanowski <marcin.krzyzanowski@gmail.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

public protocol CryptoIntegerProtocol: ByteConvertible, BitshiftOperationsProtocol {
    static func makeInteger(with bytes: [UInt8]) -> Self
    mutating func shiftLeft(_ count: Int) -> Self
    mutating func shiftRight(_ count: Int) -> Self
}

extension CryptoIntegerProtocol {
    public func bytes(_ totalBytes: Int = MemoryLayout<Self>.size) -> [UInt8] {
        return arrayOfBytes(self, length: totalBytes)
    }
    
//    public static func makeInteger(with bytes: ArraySlice<UInt8>) -> Self {
//        let b = [UInt8](
//        return Self.makeInteger(with: b)
//    }
}

extension Int:CryptoIntegerProtocol {
    public static func makeInteger(with bytes: [UInt8]) -> Int {
        return integerWithBytes(bytes)
    }
    
    /** Shift bits to the left. All bits are shifted (including sign bit) */
    public mutating func shiftLeft(_ count: Int) -> Int {
        self = MongoCryptoEssentials.shiftLeft(self, count: count) //FIXME: count:
        return self
    }
    
    /** Shift bits to the right. All bits are shifted (including sign bit) */
    public mutating func shiftRight(_ count: Int) -> Int {
        if (self == 0) {
            return self
        }
        
        let count = Int(count)
        
        let bitsCount = Int(MemoryLayout<Int>.size * 8)
        
        if (count >= bitsCount) {
            return 0
        }
        
        let maxBitsForValue = Int(floor(log2(Double(self)) + 1))
        let shiftCount = Swift.min(count, Int(maxBitsForValue - 1))
        var shiftedValue: Int = 0;
        
        for bitIdx in 0..<bitsCount {
            // if bit is set then copy to result and shift left 1
            let bit = 1 << bitIdx
            if ((self & bit) == bit) {
                shiftedValue = shiftedValue | (bit >> shiftCount)
            }
        }
        self = shiftedValue
        return self
    }
}

extension UInt:CryptoIntegerProtocol {
    public static func makeInteger(with bytes: [UInt8]) -> UInt {
        return integerWithBytes(bytes)
    }
    
    /** Shift bits to the left. All bits are shifted (including sign bit) */
    public mutating func shiftLeft(_ count: Int) -> UInt {
        self = MongoCryptoEssentials.shiftLeft(self, count: count) //FIXME: count:
        return self
    }
    
    /** Shift bits to the right. All bits are shifted (including sign bit) */
    public mutating func shiftRight(_ count: Int) -> UInt {
        if (self == 0) {
            return self
        }
        
        let count = UInt(count)
        
        let bitsCount = UInt(MemoryLayout<UInt>.size * 8)
        
        if (count >= bitsCount) {
            return 0
        }
        
        let maxBitsForValue = UInt(floor(log2(Double(self)) + 1))
        let shiftCount = Swift.min(count, UInt(maxBitsForValue - 1))
        var shiftedValue: UInt = 0;
        
        for bitIdx in 0..<bitsCount {
            // if bit is set then copy to result and shift left 1
            let bit = 1 << bitIdx
            if ((self & bit) == bit) {
                shiftedValue = shiftedValue | (bit >> shiftCount)
            }
        }
        self = shiftedValue
        return self
    }
}

extension UInt8:CryptoIntegerProtocol {
    public static func makeInteger(with bytes: [UInt8]) -> UInt8 {
        return integerWithBytes(bytes)
    }
    
    /** Shift bits to the left. All bits are shifted (including sign bit) */
    public mutating func shiftLeft(_ count: Int) -> UInt8 {
        self = MongoCryptoEssentials.shiftLeft(self, count: count) //FIXME: count:
        return self
    }
    
    /** Shift bits to the right. All bits are shifted (including sign bit) */
    public mutating func shiftRight(_ count: Int) -> UInt8 {
        if (self == 0) {
            return self
        }
        
        let count = UInt8(count)
        
        let bitsCount = UInt8(MemoryLayout<UInt8>.size * 8)
        
        if (count >= bitsCount) {
            return 0
        }
        
        let maxBitsForValue = UInt8(floor(log2(Double(self)) + 1))
        let shiftCount = Swift.min(count, UInt8(maxBitsForValue - 1))
        var shiftedValue: UInt8 = 0;
        
        for bitIdx in 0..<bitsCount {
            // if bit is set then copy to result and shift left 1
            let bit = 1 << bitIdx
            if ((self & bit) == bit) {
                shiftedValue = shiftedValue | (bit >> shiftCount)
            }
        }
        self = shiftedValue
        return self
    }
}

extension UInt16:CryptoIntegerProtocol {
    public static func makeInteger(with bytes: [UInt8]) -> UInt16 {
        return integerWithBytes(bytes)
    }
    
    /** Shift bits to the left. All bits are shifted (including sign bit) */
    public mutating func shiftLeft(_ count: Int) -> UInt16 {
        self = MongoCryptoEssentials.shiftLeft(self, count: count) //FIXME: count:
        return self
    }
    
    /** Shift bits to the right. All bits are shifted (including sign bit) */
    public mutating func shiftRight(_ count: Int) -> UInt16 {
        if (self == 0) {
            return self
        }
        
        let count = UInt16(count)
        
        let bitsCount = UInt16(MemoryLayout<UInt16>.size * 8)
        
        if (count >= bitsCount) {
            return 0
        }
        
        let maxBitsForValue = UInt16(floor(log2(Double(self)) + 1))
        let shiftCount = Swift.min(count, UInt16(maxBitsForValue - 1))
        var shiftedValue: UInt16 = 0;
        
        for bitIdx in 0..<bitsCount {
            // if bit is set then copy to result and shift left 1
            let bit = 1 << bitIdx
            if ((self & bit) == bit) {
                shiftedValue = shiftedValue | (bit >> shiftCount)
            }
        }
        self = shiftedValue
        return self
    }
}

extension UInt32:CryptoIntegerProtocol {
    public static func makeInteger(with bytes: [UInt8]) -> UInt32 {
        return integerWithBytes(bytes)
    }
    
    /** Shift bits to the left. All bits are shifted (including sign bit) */
    public mutating func shiftLeft(_ count: Int) -> UInt32 {
        self = MongoCryptoEssentials.shiftLeft(self, count: count) //FIXME: count:
        return self
    }
    
    /** Shift bits to the right. All bits are shifted (including sign bit) */
    public mutating func shiftRight(_ count: Int) -> UInt32 {
        if (self == 0) {
            return self
        }
        
        let count = UInt32(count)
        
        let bitsCount = UInt32(MemoryLayout<UInt32>.size * 8)
        
        if (count >= bitsCount) {
            return 0
        }
        
        let maxBitsForValue = UInt32(floor(log2(Double(self)) + 1))
        let shiftCount = Swift.min(count, UInt32(maxBitsForValue - 1))
        var shiftedValue: UInt32 = 0;
        
        for bitIdx in 0..<bitsCount {
            // if bit is set then copy to result and shift left 1
            let bit = 1 << bitIdx
            if ((self & bit) == bit) {
                shiftedValue = shiftedValue | (bit >> shiftCount)
            }
        }
        self = shiftedValue
        return self
    }
}

extension UInt64:CryptoIntegerProtocol {
    public static func makeInteger(with bytes: [UInt8]) -> UInt64 {
        return integerWithBytes(bytes)
    }
    
    /** Shift bits to the left. All bits are shifted (including sign bit) */
    public mutating func shiftLeft(_ count: Int) -> UInt64 {
        self = MongoCryptoEssentials.shiftLeft(self, count: count) //FIXME: count:
        return self
    }
    
    /** Shift bits to the right. All bits are shifted (including sign bit) */
    public mutating func shiftRight(_ count: Int) -> UInt64 {
        if (self == 0) {
            return self
        }
        
        let count = UInt64(count)
        
        let bitsCount = UInt64(MemoryLayout<UInt64>.size * 8)
        
        if (count >= bitsCount) {
            return 0
        }
        
        let maxBitsForValue = UInt64(floor(log2(Double(self)) + 1))
        let shiftCount = Swift.min(count, UInt64(maxBitsForValue - 1))
        var shiftedValue: UInt64 = 0;
        
        for bitIdx in 0..<bitsCount {
            // if bit is set then copy to result and shift left 1
            let bit = 1 << bitIdx
            if ((self & bit) == bit) {
                shiftedValue = shiftedValue | (bit >> shiftCount)
            }
        }
        self = shiftedValue
        return self
    }
}

// Left operator

/** shift left and assign with bits truncation */
public func &<<=<T: CryptoIntegerProtocol> ( lhs: inout T, rhs: Int) {
    let _ = lhs.shiftLeft(rhs)
}

/** shift left with bits truncation */
public func &<<<T: CryptoIntegerProtocol> (lhs: T, rhs: Int) -> T {
    var l = lhs;
    let _ = l.shiftLeft(rhs)
    return l
}

// Right operator
/** shift right and assign with bits truncation */
func &>>=<T: CryptoIntegerProtocol> ( lhs: inout T, rhs: Int) {
    let _ = lhs.shiftRight(rhs)
}

/** shift right and assign with bits truncation */
func &>><T: CryptoIntegerProtocol> (lhs: T, rhs: Int) -> T {
    var l = lhs;
    let _ = l.shiftRight(rhs)
    return l
}
