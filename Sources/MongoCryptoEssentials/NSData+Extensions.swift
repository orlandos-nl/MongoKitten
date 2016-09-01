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

import Foundation


extension NSData {
    /// Two octet checksum as defined in RFC-4880. Sum of all octets, mod 65536
    public var checksum: UInt16 {
        var s:UInt32 = 0
        var bytesArray = self.byteArray
        for i in 0..<bytesArray.count {
            s = s + UInt32(bytesArray[i])
        }
        s = s % 65536
        return UInt16(s)
    }
    
    public var base64: String {
        #if os(Linux)
            return self.base64EncodedString([.encoding64CharacterLineLength])
        #else
            return self.base64EncodedString(options: .lineLength64Characters)
        #endif
    }
    
    public var hexString: String {
        return self.byteArray.hexString
    }
    
    public var byteArray: [UInt8] {
        let count = self.length / MemoryLayout<UInt8>.size
        var bytesArray = [UInt8](repeating: 0, count: count)
        self.getBytes(&bytesArray, length:count * MemoryLayout<UInt8>.size)
        return bytesArray
    }
    
    public convenience init(bytes: [UInt8]) {
        self.init(bytes: bytes, length: bytes.count)
    }
    
    public static func withBytes(_ bytes: [UInt8]) -> NSData {
        return NSData(bytes: bytes)
    }

    public convenience init?(base64: String) {
        self.init(base64Encoded: base64, options: [])
    }
}
