public protocol Hash: Sendable {
    static var littleEndian: Bool { get }
    static var chunkSize: Int { get }
    static var digestSize: Int { get }
    
    var processedBytes: UInt64 { get }
    var hashValue: [UInt8] { get }
    
    mutating func reset()
    mutating func update(from pointer: UnsafePointer<UInt8>)
}

#if swift(<5.8)
extension UnsafeMutablePointer {
    func update(from source: UnsafePointer<Pointee>, count: Int) {
        self.assign(from: source, count: count)
    }
}
#endif


extension Hash {
    public mutating func finish(from pointer: UnsafeBufferPointer<UInt8>) -> [UInt8] {
        // Hash size in _bits_
        let hashSize = (UInt64(pointer.count) &+ processedBytes) &* 8
        
        var needed = (pointer.count + 9)
        let remainder = needed % Self.chunkSize
        
        if remainder != 0 {
            needed = needed - remainder + Self.chunkSize
        }
        
        var data = [UInt8](repeating: 0, count: needed)
        data.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.update(from: pointer.baseAddress!, count: pointer.count)
            
            buffer[pointer.count] = 0x80
            
            buffer.baseAddress!.advanced(by: needed &- 8).withMemoryRebound(to: UInt64.self, capacity: 1) { pointer in
                if Self.littleEndian {
                    pointer.pointee = hashSize.littleEndian
                } else {
                    pointer.pointee = hashSize.bigEndian
                }
            }
            
            var offset = 0
            
            while offset < needed {
                self.update(from: buffer.baseAddress!.advanced(by: offset))
                
                offset = offset &+ Self.chunkSize
            }
        }
        
        return self.hashValue
    }
    
    public mutating func hash(bytes data: [UInt8]) -> [UInt8] {
        defer {
            self.reset()
        }
        
        return data.withUnsafeBufferPointer { buffer in
            self.finish(from: buffer)
        }
    }
    
    public mutating func hash(_ data: UnsafePointer<UInt8>, count: Int) -> [UInt8] {
        defer {
            self.reset()
        }
        
        let buffer = UnsafeBufferPointer(start: data, count: count)
        
        return finish(from: buffer)
    }
}
