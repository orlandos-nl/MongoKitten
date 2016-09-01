// Originally based on CryptoSwift by Marcin Krzyżanowski <marcin.krzyzanowski@gmail.com>
// Copyright (C) 2014 Marcin Krzyżanowski <marcin.krzyzanowski@gmail.com>
// This software is provided 'as-is', without any express or implied warranty.
//
// In no event will the authors be held liable for any damages arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
// - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
// - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
// - This notice may not be removed or altered from any source or binary distribution.



/** Protocol and extensions for integerFromBitsArray. Bit hakish for me, but I can't do it in any other way */
public protocol Initiable  {
    init(_ v: Int)
    init(_ v: UInt)
}

extension Int:Initiable {}
extension UInt:Initiable {}
extension UInt8:Initiable {}
extension UInt16:Initiable {}
extension UInt32:Initiable {}
extension UInt64:Initiable {}

/// Initialize integer from array of bytes.
/// This method may be slow
public func integerWithBytes<T: Integer>(_ bytes: [UInt8]) -> T where T:ByteConvertible, T: BitshiftOperationsProtocol {
    var bytes = bytes.reversed() as [UInt8] //FIXME: check it this is equivalent of Array(...)
    if bytes.count < MemoryLayout<T>.size {
        let paddingCount = MemoryLayout<T>.size - bytes.count
        if (paddingCount > 0) {
            bytes += [UInt8](repeating: 0, count: paddingCount)
        }
    }
    
    if MemoryLayout<T>.size == 1 {
        return T(truncatingBitPattern: UInt64(bytes.first!))
    }
    
    var result: T = 0
    for byte in bytes.reversed() {
        result = result << 8 | T(byte)
    }
    return result
}

/// Array of bytes, little-endian representation. Don't use if not necessary.
/// I found this method slow
public func arrayOfBytes<T>(_ value:T, length:Int? = nil) -> [UInt8] {
    let totalBytes = length ?? MemoryLayout<T>.size
    
    let valuePointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
    
    valuePointer.pointee = value
    
    let bytesPointer = UnsafeMutableRawPointer(valuePointer).assumingMemoryBound(to: UInt8.self)
    var bytes = [UInt8](repeating: 0, count: totalBytes)
    for j in 0..<min(MemoryLayout<T>.size,totalBytes) {
        bytes[totalBytes - 1 - j] = (bytesPointer + j).pointee
    }
    
    valuePointer.deinitialize()
    valuePointer.deallocate(capacity: 1)
    
    return bytes
}

// MARK: - shiftLeft

// helper to be able tomake shift operation on T
public func << <T:SignedInteger>(lhs: T, rhs: Int) -> Int {
    let a = lhs as! Int
    let b = rhs
    return a << b
}

public func << <T:UnsignedInteger>(lhs: T, rhs: Int) -> UInt {
    let a = lhs as! UInt
    let b = rhs
    return a << b
}

// Generic function itself
// FIXME: this generic function is not as generic as I would. It crashes for smaller types
public func shiftLeft<T: SignedInteger>(_ value: T, count: Int) -> T where T: Initiable {
    if (value == 0) {
        return 0;
    }
    
    let bitsCount = (MemoryLayout<T>.size * 8)
    let shiftCount = Int(Swift.min(count, bitsCount - 1))
    
    var shiftedValue:T = 0;
    for bitIdx in 0..<bitsCount {
        let bit = T(IntMax(1 << bitIdx))
        if ((value & bit) == bit) {
            shiftedValue = shiftedValue | T(bit << shiftCount)
        }
    }
    
    if (shiftedValue != 0 && count >= bitsCount) {
        // clear last bit that couldn't be shifted out of range
        shiftedValue = shiftedValue & T(~(1 << (bitsCount - 1)))
    }
    return shiftedValue
}

// for any f*** other Integer type - this part is so non-Generic
public func shiftLeft(_ value: UInt, count: Int) -> UInt {
    return UInt(shiftLeft(Int(value), count: count)) //FIXME: count:
}

public func shiftLeft(_ value: UInt8, count: Int) -> UInt8 {
    return UInt8(shiftLeft(UInt(value), count: count))
}

public func shiftLeft(_ value: UInt16, count: Int) -> UInt16 {
    return UInt16(shiftLeft(UInt(value), count: count))
}

public func shiftLeft(_ value: UInt32, count: Int) -> UInt32 {
    return UInt32(shiftLeft(UInt(value), count: count))
}

public func shiftLeft(_ value: UInt64, count: Int) -> UInt64 {
    return UInt64(shiftLeft(UInt(value), count: count))
}

public func shiftLeft(_ value: Int8, count: Int) -> Int8 {
    return Int8(shiftLeft(Int(value), count: count))
}

public func shiftLeft(_ value: Int16, count: Int) -> Int16 {
    return Int16(shiftLeft(Int(value), count: count))
}

public func shiftLeft(_ value: Int32, count: Int) -> Int32 {
    return Int32(shiftLeft(Int(value), count: count))
}

public func shiftLeft(_ value: Int64, count: Int) -> Int64 {
    return Int64(shiftLeft(Int(value), count: count))
}
