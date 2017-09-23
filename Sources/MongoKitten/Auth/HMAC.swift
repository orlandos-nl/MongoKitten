import Foundation

final class HMAC_SHA1 {
    /// Authenticates a message using the provided `Hash` algorithm
    ///
    /// - parameter message: The message to authenticate
    /// - parameter key: The key to authenticate with
    ///
    /// - returns: The authenticated message
    static func authenticate(_ message: Data, withKey key: Data) -> Data {
        var key = key
        
        // If it's too long, hash it first
        if key.count > SHA1.chunkSize {
            key = SHA1.hash(key)
        }
        
        // Add padding
        if key.count < SHA1.chunkSize {
            key = key + Data(repeating: 0, count: SHA1.chunkSize - key.count)
        }
        
        // XOR the information
        var outerPadding = Data(repeating: 0x5c, count: SHA1.chunkSize)
        var innerPadding = Data(repeating: 0x36, count: SHA1.chunkSize)
        
        for i in 0..<key.count {
            outerPadding[i] = key[i] ^ outerPadding[i]
        }
        
        for i in 0..<key.count {
            innerPadding[i] = key[i] ^ innerPadding[i]
        }
        
        // Hash the information
        let innerPaddingHash: Data = SHA1.hash(innerPadding + message)
        let outerPaddingHash: Data = SHA1.hash(outerPadding + innerPaddingHash)
        
        return outerPaddingHash
    }
}
