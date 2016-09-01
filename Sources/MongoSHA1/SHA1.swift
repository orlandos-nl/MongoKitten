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

@_exported import MongoCryptoEssentials
import Foundation

public final class SHA1 : HashProtocol {
    private static let h:[UInt32] = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]
    public static let size: Int = 64
    
    public static func calculate(_ message: NSData) -> NSData {
        return NSData(bytes: calculate(message.byteArray))
    }
    
    public static func calculate(_ message: String) -> [UInt8] {
        return self.calculate([UInt8](message.utf8))
    }
    
    public static func calculate(_ message: [UInt8]) -> [UInt8] {
        var tmpMessage = message
        
        let len = 64
        
        // Step 1. Append Padding Bits
        tmpMessage.append(0x80) // append one bit (UInt8 with one bit) to message
        
        // append "0" bit until message length in bits ≡ 448 (mod 512)
        var msgLength = tmpMessage.count
        var counter = 0
        
        while msgLength % len != (len - 8) {
            counter += 1
            msgLength += 1
        }
        
        tmpMessage += [UInt8](repeating: 0, count: counter)
        
        // hash values
        var hh = h
        
        // append message length, in a 64-bit big-endian integer. So now the message length is a multiple of 512 bits.
        tmpMessage += arrayOfBytes(message.count * 8, length: 64 / 8)
        
        // Process the message in successive 512-bit chunks:
        let chunkSizeBytes = 512 / 8 // 64
        for chunk in BytesSequence(chunkSize: chunkSizeBytes, data: tmpMessage) {
            // break chunk into sixteen 32-bit words M[j], 0 ≤ j ≤ 15, big-endian
            // Extend the sixteen 32-bit words into eighty 32-bit words:
            var M:[UInt32] = [UInt32](repeating: 0, count: 80)
            for x in 0..<M.count {
                switch (x) {
                case 0...15:
                    let start = chunk.startIndex + (x * MemoryLayout<UInt32>.size)
                    let end = start + MemoryLayout<UInt32>.size
                    let le = toUInt32Array(chunk[start..<end])[0]
                    M[x] = le.bigEndian
                    break
                default:
                    M[x] = rotateLeft(M[x-3] ^ M[x-8] ^ M[x-14] ^ M[x-16], 1) //FIXME: n:
                    break
                }
            }
            
            var A = hh[0]
            var B = hh[1]
            var C = hh[2]
            var D = hh[3]
            var E = hh[4]
            
            // Main loop
            for j in 0...79 {
                var f: UInt32 = 0;
                var k: UInt32 = 0
                
                switch (j) {
                case 0...19:
                    f = (B & C) | ((~B) & D)
                    k = 0x5A827999
                    break
                case 20...39:
                    f = B ^ C ^ D
                    k = 0x6ED9EBA1
                    break
                case 40...59:
                    f = (B & C) | (B & D) | (C & D)
                    k = 0x8F1BBCDC
                    break
                case 60...79:
                    f = B ^ C ^ D
                    k = 0xCA62C1D6
                    break
                default:
                    break
                }
                
                let temp = (rotateLeft(A,5) &+ f &+ E &+ M[j] &+ k) & 0xffffffff
                E = D
                D = C
                C = rotateLeft(B, 30)
                B = A
                A = temp
            }
            
            hh[0] = (hh[0] &+ A) & 0xffffffff
            hh[1] = (hh[1] &+ B) & 0xffffffff
            hh[2] = (hh[2] &+ C) & 0xffffffff
            hh[3] = (hh[3] &+ D) & 0xffffffff
            hh[4] = (hh[4] &+ E) & 0xffffffff
        }
        
        // Produce the final hash value (big-endian) as a 160 bit number:
        var result = [UInt8]()
        result.reserveCapacity(hh.count / 4)
        hh.forEach {
            let item = $0.bigEndian
            result += [UInt8(item & 0xff), UInt8((item >> 8) & 0xff), UInt8((item >> 16) & 0xff), UInt8((item >> 24) & 0xff)]
        }
        return result
    }
}

public extension String {
    public func sha1() -> [UInt8] {
        return SHA1.calculate([UInt8](self.utf8))
    }
}

#if !swift(>=3.0)
    public extension ArrayProtocol where Generator.Element == UInt8 {
        public func sha1() -> [UInt8] {
            return SHA1.calculate(self.arrayValue())
        }
    }
#else
    public extension ArrayProtocol where Iterator.Element == UInt8 {
        public func sha1() -> [UInt8] {
            return SHA1.calculate(self.arrayValue())
        }
    }
#endif
