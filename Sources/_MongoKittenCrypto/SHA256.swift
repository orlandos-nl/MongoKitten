fileprivate let k: [UInt32] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
]

public struct SHA256 : Hash {
    public static let littleEndian = false
    public static let chunkSize = 64
    public static let digestSize = 32
    
    var h0: UInt32 = 0x6a09e667
    var h1: UInt32 = 0xbb67ae85
    var h2: UInt32 = 0x3c6ef372
    var h3: UInt32 = 0xa54ff53a
    var h4: UInt32 = 0x510e527f
    var h5: UInt32 = 0x9b05688c
    var h6: UInt32 = 0x1f83d9ab
    var h7: UInt32 = 0x5be0cd19

    var a: UInt32 = 0
    var b: UInt32 = 0
    var c: UInt32 = 0
    var d: UInt32 = 0
    var e: UInt32 = 0
    var f: UInt32 = 0
    var g: UInt32 = 0
    var h: UInt32 = 0
    
    var s0: UInt32 = 0
    var s1: UInt32 = 0
    var ch: UInt32 = 0
    var maj: UInt32 = 0
    
    var temp: UInt32 = 0
    var temp1: UInt32 = 0
    var temp2: UInt32 = 0
    
    public var processedBytes: UInt64 = 0
    
    public mutating func reset() {
        h0 = 0x6a09e667
        h1 = 0xbb67ae85
        h2 = 0x3c6ef372
        h3 = 0xa54ff53a
        h4 = 0x510e527f
        h5 = 0x9b05688c
        h6 = 0x1f83d9ab
        h7 = 0x5be0cd19
        processedBytes = 0
    }
    
    @_optimize(speed)
    public var hashValue: [UInt8] {
        var buffer = [UInt8]()
        buffer.reserveCapacity(32)
        
        func convert(_ int: UInt32) {
            let int = int.bigEndian
            
            buffer.append(UInt8(truncatingIfNeeded: int & 0xff))
            buffer.append(UInt8(truncatingIfNeeded: (int &>> 8) & 0xff))
            buffer.append(UInt8(truncatingIfNeeded: (int &>> 16) & 0xff))
            buffer.append(UInt8(truncatingIfNeeded: (int &>> 24) & 0xff))
        }
        
        convert(h0)
        convert(h1)
        convert(h2)
        convert(h3)
        convert(h4)
        convert(h5)
        convert(h6)
        convert(h7)
        
        return buffer
    }
    
    public init() {
        reset()
    }
    
    @_optimize(speed)
    public mutating func update(from pointer: UnsafePointer<UInt8>) {
        var i = 16
        let w = [UInt32](unsafeUninitializedCapacity: 64) { buf, count in
            buf.initialize(repeating: 0)
            pointer.withMemoryRebound(to: UInt32.self, capacity: 16, { pointer in
                (buf[ 0], buf[ 1], buf[ 2], buf[ 3]) = (pointer[ 0].bigEndian, pointer[ 1].bigEndian, pointer[ 2].bigEndian, pointer[ 3].bigEndian)
                (buf[ 4], buf[ 5], buf[ 6], buf[ 7]) = (pointer[ 4].bigEndian, pointer[ 5].bigEndian, pointer[ 6].bigEndian, pointer[ 7].bigEndian)
                (buf[ 8], buf[ 9], buf[10], buf[11]) = (pointer[ 8].bigEndian, pointer[ 9].bigEndian, pointer[10].bigEndian, pointer[11].bigEndian)
                (buf[12], buf[13], buf[14], buf[15]) = (pointer[12].bigEndian, pointer[13].bigEndian, pointer[14].bigEndian, pointer[15].bigEndian)
            })
            while i < 64 {
                let j = i &- 15, k = i &- 2
                s0 = rightRotate(buf[j], count: 7) ^ rightRotate(buf[j], count: 18) ^ (buf[j] &>> 3)
                s1 = rightRotate(buf[k], count: 17) ^ rightRotate(buf[k], count: 19) ^ (buf[k] &>> 10)
                buf[i] = buf[i &- 16] &+ s0 &+ buf[i &- 7] &+ s1
                i &+= 1
            }
            count = buf.count
        }

        a = h0
        b = h1
        c = h2
        d = h3
        e = h4
        f = h5
        g = h6
        h = h7
        
        i = 0
        k.withUnsafeBufferPointer { k in
            w.withUnsafeBufferPointer { w in
                while i < 64 {
                    s1 = rightRotate(e, count: 6) ^ rightRotate(e, count: 11) ^  rightRotate(e, count: 25)
                    ch = (e & f) ^ ((~e) & g)
                    temp1 = h &+ s1 &+ ch &+ k[i] &+ w[i]
                    s0 = rightRotate(a, count: 2) ^  rightRotate(a, count: 13) ^  rightRotate(a, count: 22)
                    maj = (a & b) ^ (a & c) ^ (b & c)
                    temp2 = s0 &+ maj
                    
                    h = g
                    g = f
                    f = e
                    e = d &+ temp1
                    d = c
                    c = b
                    b = a
                    a = temp1 &+ temp2
                    i &+= 1
                }
            }
        }
        
        h0 &+= a
        h1 &+= b
        h2 &+= c
        h3 &+= d
        h4 &+= e
        h5 &+= f
        h6 &+= g
        h7 &+= h
    }
}

@_transparent
@_optimize(speed)
fileprivate func rightRotate(_ x: UInt32, count c: UInt32) -> UInt32 {
    return (x &>> c) | (x &<< (32 &- c))
}
