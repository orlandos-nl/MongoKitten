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
        containedRemainder = 0
        totalLength = 0
    }
    
    deinit {
        self.remainder.deallocate(capacity: 63)
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
        var w = pointer.withMemoryRebound(to: UInt32.self, capacity: 16, { pointer in
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
    
    /// Processes the contents of this `Data` and returns the resulting hash
     static func hash(_ data: Data) -> Data {
        let h = SHA1()
        
        return Array(data).withUnsafeBufferPointer { buffer in
            h.finalize(buffer)
            return h.hash
        }
    }
    
    /// Processes the contents of this ByteBuffer and returns the resulting hash
     static func hash(_ data: UnsafeBufferPointer<UInt8>) -> Data {
        let h = SHA1()
        
        h.finalize(data)
        return h.hash
    }
    
    /// Processes the contents of this byte sequence
    ///
    /// Doesn't finalize the hash and thus doesn't return any results
     func finalize(_ data: Data) {
        Array(data).withUnsafeBufferPointer { buffer in
            self.finalize(buffer)
        }
    }
    
    /// Finalizes the hash by appending a `0x80` and `0x00` until there are 64 bits left. Then appends a `UInt64` with little or big endian as defined in the protocol implementation
     func finalize(_ buffer: UnsafeBufferPointer<UInt8>? = nil) {
        let totalRemaining = containedRemainder + (buffer?.count ?? 0) + 1
        totalLength = totalLength &+ (UInt64(buffer?.count ?? 0) &* 8)
        
        // Append zeroes
        var zeroes = lastChunkSize &- (totalRemaining % SHA1.chunkSize)
        
        if zeroes > lastChunkSize {
            // Append another chunk of zeroes if we have more than 448 bits
            zeroes = (SHA1.chunkSize &+ (lastChunkSize &- zeroes)) &+ zeroes
        }
        
        // If there isn't enough room, add another big chunk of zeroes until there is room
        if zeroes < 0 {
            zeroes =  (8 &+ zeroes) + lastChunkSize
        }
        
        var length = [UInt8](repeating: 0, count: 8)
        
        // Append UInt64 length in bits
        _ = length.withUnsafeMutableBytes { length in
            memcpy(length.baseAddress!, &totalLength, 8)
        }
        
        // Little endian is reversed
        if !SHA1.littleEndian {
            length.reverse()
        }
        
        var lastBlocks: [UInt8]
        
        if let buffer = buffer {
            lastBlocks = Array(buffer)
        } else {
            lastBlocks = []
        }
        
        lastBlocks = lastBlocks + [0x80] + Data(repeating: 0, count: zeroes) + length
        
        var offset = 0
        
        lastBlocks.withUnsafeBufferPointer { buffer in
            let pointer = buffer.baseAddress!
            
            while offset < buffer.count {
                defer { offset = offset &+ SHA1.chunkSize }
                self.update(pointer: pointer.advanced(by: offset))
            }
        }
    }
    
    /// Updates the hash using the contents of this buffer
    ///
    /// Doesn't finalize the hash
     func update(_ buffer: UnsafeBufferPointer<UInt8>) {
        totalLength = totalLength &+ UInt64(buffer.count)
        
        var buffer = buffer
        
        // If there was data from a previous chunk that needs to be processed, process that with this buffer, first
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
        
        // The buffer *must* have a baseAddress to read from
        guard var bufferPointer = buffer.baseAddress else {
            assertionFailure("Invalid hashing buffer provided")
            return
        }
        
        var bufferSize = buffer.count
        
        // Process the input in chunks of `chunkSize`
        while bufferSize >= SHA1.chunkSize {
            defer {
                bufferPointer = bufferPointer.advanced(by: SHA1.chunkSize)
                bufferSize = bufferSize &- SHA1.chunkSize
            }
            
            update(pointer: bufferPointer)
        }
        
        // Append the remaining data to the internal remainder buffer
        memcpy(remainder, bufferPointer, bufferSize)
        containedRemainder = bufferSize
    }
    
    /// Updates the hash with the contents of this byte sequence
    ///
    /// Does not finalize
     func update<S: Sequence>(sequence: inout S) where S.Element == UInt8 {
        Array(sequence).withUnsafeBufferPointer { buffer in
            update(buffer)
        }
    }
}

fileprivate func leftRotate(_ x: UInt32, count c: UInt32) -> UInt32 {
    return (x << c) | (x >> (32 - c))
}

