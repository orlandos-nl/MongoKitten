public struct HMAC<H: Hash> {
    private var hasher: H
    
    public init(hasher: H) {
        self.hasher = hasher
    }
    
    public mutating func authenticate(_ message: [UInt8], withKey key: [UInt8]) -> [UInt8] {
        let keyLength = key.count
        var key = key
        
        var op = [UInt8](repeating: 0x5c, count: H.chunkSize)
        var ip = [UInt8](repeating: 0x36, count: H.chunkSize)
        
        if keyLength > H.chunkSize {
            key = hasher.hash(bytes: key)
        } else if keyLength < H.chunkSize {
            key += [UInt8](repeating: 0, count: H.chunkSize &- keyLength)
        }
        
        xor(&op, key)
        xor(&ip, key)
        
        let hashedMessage = hasher.hash(bytes: ip + message)
        return hasher.hash(bytes: op + hashedMessage)
    }
}
