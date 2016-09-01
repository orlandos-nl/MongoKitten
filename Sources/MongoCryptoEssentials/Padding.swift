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

public protocol Padding {
    static func add(to data: [UInt8], blockSize:Int) -> [UInt8]
    static func remove(from data: [UInt8], blockSize:Int?) -> [UInt8]
}

public struct NoPadding: Padding {
    public static func add(to data: [UInt8], blockSize: Int) -> [UInt8] {
        return data;
    }
    
    public static func remove(from data: [UInt8], blockSize: Int?) -> [UInt8] {
        return data;
    }
}

public struct PKCS7: Padding {
    public enum Error: Swift.Error {
        case InvalidPaddingValue
    }
    
    public static func add(to bytes: [UInt8], blockSize:Int) -> [UInt8] {
        let padding = UInt8(blockSize - (bytes.count % blockSize))
        var withPadding = bytes
        if (padding == 0) {
            // If the original data is a multiple of N bytes, then an extra block of bytes with value N is added.
            for _ in 0..<blockSize {
                withPadding.append(contentsOf: [UInt8(blockSize)])
            }
        } else {
            // The value of each added byte is the number of bytes that are added
            for _ in 0..<padding {
                withPadding.append(contentsOf: [UInt8(padding)])

            }
        }
        return withPadding
    }
    
    public static func remove(from bytes: [UInt8], blockSize:Int?) -> [UInt8] {
        assert(bytes.count > 0, "Need bytes to remove padding")
        guard bytes.count > 0, let lastByte = bytes.last else {
            return bytes
        }
        
        let padding = Int(lastByte) // last byte
        let finalLength = bytes.count - padding
        
        if finalLength < 0 {
            return bytes
        }
        
        if padding >= 1 {
            return Array(bytes[0..<finalLength])
        }
        return bytes
    }
}
