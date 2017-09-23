#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Foundation

final class SHA1 {
    static let digestSize = 20
    static let chunkSize = 64
    static let littleEndian = false
    
    var h0: UInt32 = 0x67452301
    var h1: UInt32 = 0xEFCDAB89
    var h2: UInt32 = 0x98BADCFE
    var h3: UInt32 = 0x10325476
    var h4: UInt32 = 0xC3D2E1F0
    
    var a: UInt32 = 0
    var b: UInt32 = 0
    var c: UInt32 = 0
    var d: UInt32 = 0
    var e: UInt32 = 0
    
    var f: UInt32 = 0
    var k: UInt32 = 0
    var temp: UInt32 = 0
    
    var remainder = UnsafeMutablePointer<UInt8>.allocate(capacity: 63)
    var containedRemainder = 0
    var totalLength: UInt64 = 0
    
    func reset() {
        h0 = 0x67452301
        h1 = 0xEFCDAB89
        h2 = 0x98BADCFE
        h3 = 0x10325476
        h4 = 0xC3D2E1F0
    }
    
    deinit {
        remainder.deallocate(capacity: 63)
    }
    
    var hash: Data {
        var buffer = Data()
        buffer.reserveCapacity(20)
        
        func convert(_ int: UInt32) {
            let int = int.bigEndian
            buffer.append(UInt8(int & 0xff))
            buffer.append(UInt8((int >> 8) & 0xff))
            buffer.append(UInt8((int >> 16) & 0xff))
            buffer.append(UInt8((int >> 24) & 0xff))
        }
        
        convert(h0)
        convert(h1)
        convert(h2)
        convert(h3)
        convert(h4)
        
        return buffer
    }
    
    init() {}
    
    func update(pointer: UnsafePointer<UInt8>) {
        var w = pointer.withMemoryRebound(to: UInt32.SHA1, capacity: 16, { pointer in
            return [
                pointer[0].bigEndian, pointer[1].bigEndian, pointer[2].bigEndian, pointer[3].bigEndian,
                pointer[4].bigEndian, pointer[5].bigEndian, pointer[6].bigEndian, pointer[7].bigEndian,
                pointer[8].bigEndian, pointer[9].bigEndian, pointer[10].bigEndian, pointer[11].bigEndian,
                pointer[12].bigEndian, pointer[13].bigEndian, pointer[14].bigEndian, pointer[15].bigEndian,
                ]
        })
        
        w.reserveCapacity(80)
        
        for i in 16...79 {
            w.append(leftRotate(w[i &- 3] ^ w[i &- 8] ^ w[i &- 14] ^ w[i &- 16], count: 1))
        }
        
        a = h0
        b = h1
        c = h2
        d = h3
        e = h4
        
        for i in 0...79 {
            switch i {
            case 0...19:
                f = (b & c) | ((~b) & d)
                k = 0x5A827999
            case 20...39:
                f = b ^ c ^ d
                k = 0x6ED9EBA1
            case 40...59:
                f = (b & c) | (b & d) | (c & d)
                k = 0x8F1BBCDC
            default:
                f = b ^ c ^ d
                k = 0xCA62C1D6
            }
            
            temp = leftRotate(a, count: 5) &+ f &+ e &+ w[i] &+ k
            e = d
            d = c
            c = leftRotate(b, count: 30)
            b = a
            a = temp
        }
        
        h0 = h0 &+ a
        h1 = h1 &+ b
        h2 = h2 &+ c
        h3 = h3 &+ d
        h4 = h4 &+ e
    }
    
    fileprivate var lastChunkSize: Int {
        return SHA1.chunkSize &- 8
    }
    
    static func hash(_ buffer: UnsafeBufferPointer<UInt8>) -> Data {
        let hash = SHA1()
        hash.finalize(buffer)
        return hash.hash
    }
    
    static func hash(_ data: Data) -> Data {
        return data.withUnsafeBufferPointer { buffer in
            return hash(buffer)
        }
    }
    
    func finalize(_ buffer: UnsafeBufferPointer<UInt8>) {
        let totalRemaining = containedRemainder + buffer.count + 1
        totalLength = totalLength &+ (UInt64(buffer.count) &* 8)
        
        // Append zeroes
        var zeroes = lastChunkSize &- (totalRemaining % SHA1.chunkSize)
        
        if zeroes > lastChunkSize {
            // Append another chunk of zeroes if we have more than 448 bits
            zeroes = (SHA1.chunkSize &+ (lastChunkSize &- zeroes)) &+ zeroes
        }
        
        if zeroes < 0 {
            zeroes =  (8 &+ zeroes) + lastChunkSize
        }
        
        var length = Data(repeating: 0, count: 8)
        
        // Append UInt64 length in bits
        _ = length.withUnsafeMutableBytes { length in
            memcpy(length, &totalLength, 8)
        }
        
        if !SHA1.littleEndian {
            length.reverse()
        }
        
        let lastBlocks = Array(buffer) + [0x80] + Data(repeating: 0, count: zeroes) + length
        var offset = 0
        
        lastBlocks.withUnsafeBufferPointer { buffer in
            let pointer = buffer.baseAddress!
            
            while offset < buffer.count {
                defer { offset = offset &+ SHA1.chunkSize }
                SHA1.update(pointer: pointer.advanced(by: offset))
            }
        }
    }
    
    func finalize(array: inout Data) {
        return array.withUnsafeBufferPointer { buffer in
            SHA1.finalize(buffer)
        }
    }
    
    func update(_ buffer: UnsafeBufferPointer<UInt8>) {
        totalLength = totalLength &+ UInt64(buffer.count)
        
        var buffer = buffer
        
        if containedRemainder > 0 {
            let needed = SHA1.chunkSize &- containedRemainder
            
            guard let bufferPointer = buffer.baseAddress else {
                assertionFailure("Invalid buffer provided")
                return
            }
            
            if buffer.count >= needed {
                memcpy(remainder.advanced(by: containedRemainder), bufferPointer, needed)
                
                buffer = UnsafeBufferPointer(start: bufferPointer.advanced(by: needed), count: buffer.count &- needed)
            } else {
                memcpy(remainder.advanced(by: containedRemainder), bufferPointer, buffer.count)
                return
            }
        }
        
        guard var bufferPointer = buffer.baseAddress else {
            assertionFailure("Invalid buffer provided")
            return
        }
        
        var bufferSize = buffer.count
        
        while bufferSize >= SHA1.chunkSize {
            defer {
                bufferPointer = bufferPointer.advanced(by: SHA1.chunkSize)
                bufferSize = bufferSize &- SHA1.chunkSize
            }
            
            update(pointer: bufferPointer)
        }
        
        memcpy(remainder, bufferPointer, bufferSize)
        containedRemainder = bufferSize
    }
    
    func update(array: inout Data) {
        array.withUnsafeBufferPointer { buffer in
            update(buffer)
        }
    }
}

fileprivate func leftRotate(_ x: UInt32, count c: UInt32) -> UInt32 {
    return (x << c) | (x >> (32 - c))
}

