public struct SHA1 : Hash {
    public static let littleEndian = false
    public static let chunkSize = 64
    public static let digestSize = 20
    
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
//    var temp: UInt32 = 0
    
    public var processedBytes: UInt64 = 0
    
    public mutating func reset() {
        h0 = 0x67452301
        h1 = 0xEFCDAB89
        h2 = 0x98BADCFE
        h3 = 0x10325476
        h4 = 0xC3D2E1F0
        processedBytes = 0
    }
    
    public var hashValue: [UInt8] {
        var buffer = [UInt8]()
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
    
    public init() {
        reset()
    }
    
    public mutating func update(from pointer: UnsafePointer<UInt8>) {
        var i = 16
        let w = [UInt32](unsafeUninitializedCapacity: 80) { buf, count in
            buf.initialize(repeating: 0)
            pointer.withMemoryRebound(to: UInt32.self, capacity: 16, { pointer in
                (buf[ 0], buf[ 1], buf[ 2], buf[ 3]) = (pointer[ 0].bigEndian, pointer[ 1].bigEndian, pointer[ 2].bigEndian, pointer[ 3].bigEndian)
                (buf[ 4], buf[ 5], buf[ 6], buf[ 7]) = (pointer[ 4].bigEndian, pointer[ 5].bigEndian, pointer[ 6].bigEndian, pointer[ 7].bigEndian)
                (buf[ 8], buf[ 9], buf[10], buf[11]) = (pointer[ 8].bigEndian, pointer[ 9].bigEndian, pointer[10].bigEndian, pointer[11].bigEndian)
                (buf[12], buf[13], buf[14], buf[15]) = (pointer[12].bigEndian, pointer[13].bigEndian, pointer[14].bigEndian, pointer[15].bigEndian)
            })
            while i < 80 {
                buf[i] = leftRotate(buf[i &- 3] ^ buf[i &- 8] ^ buf[i &- 14] ^ buf[i &- 16], count: 1)
                i &+= 1
            }
            count = buf.count
        }
        
        a = h0
        b = h1
        c = h2
        d = h3
        e = h4
        
        w.withUnsafeBufferPointer { w in
            i = 0
            while i < 80 {
                let f: UInt32, k: UInt32
                if i < 20 {
                    f = (b & c) | ((~b) & d)
                    k = 0x5A827999
                } else if i < 40 {
                    f = b ^ c ^ d
                    k = 0x6ED9EBA1
                } else if i < 60 {
                    f = (b & c) | (b & d) | (c & d)
                    k = 0x8F1BBCDC
                } else {
                    f = b ^ c ^ d
                    k = 0xCA62C1D6
                }
                
                let temp = leftRotate(a, count: 5) &+ f &+ e &+ w[i] &+ k
                e = d
                d = c
                c = leftRotate(b, count: 30)
                b = a
                a = temp
                i &+= 1
            }
        }
        
        h0 &+= a
        h1 &+= b
        h2 &+= c
        h3 &+= d
        h4 &+= e
    }
}

@_transparent
fileprivate func leftRotate(_ x: UInt32, count c: UInt32) -> UInt32 {
    return (x &<< c) | (x &>> (32 &- c))
}
