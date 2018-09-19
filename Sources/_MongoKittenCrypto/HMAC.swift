public struct HMAC<H: Hash> {
    private var hasher: H
    private let chunkSize: Int
    
    public init(hasher: H) {
        self.hasher = hasher
        self.chunkSize = H.chunkSize
    }
    
    public mutating func authenticate(_ message: [UInt8], withKey key: [UInt8]) -> [UInt8] {
        let keyLength = key.count
        var key = key
        
        var op = [UInt8](repeating: 0x5c, count: chunkSize)
        var ip = [UInt8](repeating: 0x36, count: chunkSize)
        
        if key.count > chunkSize {
            key = hasher.hash(bytes: key)
        }
        
        if key.count < chunkSize {
            key += [UInt8](repeating: 0, count: chunkSize &- keyLength)
        }
        
        xor(&op, key)
        xor(&ip, key)
        
        let hashedMessage = hasher.hash(bytes: ip + message)
        return hasher.hash(bytes: op + hashedMessage)
    }
}
