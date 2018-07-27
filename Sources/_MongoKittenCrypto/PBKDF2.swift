import Foundation

/// The requested amount of output bytes from the key derivation
///
/// In circumstances with low iterations the amount of output bytes may not be met.
///
/// `digest.digestSize * iterations` is the amount of bytes stored in PBKDF2's buffer.
/// Any data added beyond this limit
///
/// WARNING: Do not switch these key sizes, new sizes may be added
public enum PBKDF2KeySize {
    case digestSize
    case fixed(Int)
    
    fileprivate func size(for digest: Hash) -> Int {
        switch self {
        case .digestSize:
            return numericCast(type(of: digest).digestSize)
        case .fixed(let size):
            return size
        }
    }
}

/// PBKDF2 derives a fixed or custom length key from a password and salt.
///
/// It accepts a customizable amount of iterations to increase the algorithm weight and security.
///
/// Unlike BCrypt, the salt does not get stored in the final result,
/// meaning it needs to be generated and stored manually.
///
///     let passwordHasher = PBKDF2(digest: SHA1)
///     let salt = try CryptoRandom().generateData(count: 64) // Data
///     let hash = try passwordHasher.deriveKey(fromPassword: "secret", salt: salt, iterations: 15_000) // Data
///     print(hash.hexEncodedString()) // 8e55fa3015da583bb51b706371aa418afc8a0a44
///
/// PBKDF2 leans on HMAC for each iteration and can use all hash functions supported in Crypto
///
/// https://en.wikipedia.org/wiki/PBKDF2
public final class PBKDF2 {
    private var hash: Hash
    private let chunkSize: Int
    private let digestSize: Int
    
    /// MD5 digest powered key derivation.
    ///
    /// https://en.wikipedia.org/wiki/MD5
    public static var md5: PBKDF2 { return .init(digest: MD5()) }
    
    /// SHA-1 digest powered key derivation.
    ///
    /// https://en.wikipedia.org/wiki/SHA-1
    public static var sha1: PBKDF2 { return .init(digest: SHA1()) }
    
    /// Creates a new PBKDF2 derivator based on a hashing algorithm
    public init(digest: Hash) {
        self.hash = digest
        self.chunkSize = type(of: hash).chunkSize
        self.digestSize = type(of: hash).digestSize
    }
    
    /// Derives a key with up to `keySize` of bytes
    public func hash(
        _ password: [UInt8],
        salt: [UInt8],
        iterations: Int32,
        keySize: PBKDF2KeySize = .digestSize
    ) -> [UInt8] {
        precondition(iterations > 0, "You must iterate in PBKDF2 at least once")
        precondition(password.count > 0, "You cannot hash an empty password")
        precondition(salt.count > 0, "You cannot hash with an empty salt")
        
        let keySize = keySize.size(for: hash)
        
        precondition(keySize <= Int(((pow(2,32) as Double) - 1) * Double(chunkSize)))
        
        let saltSize = salt.count
        var salt = salt + [0, 0, 0, 0]
        var output = [UInt8]()
        output.reserveCapacity(keySize)
        
        return salt.withUnsafeMutableBytes { salt in
            guard let saltPointer = salt.baseAddress else {
                fatalError("Invalid internal state, buffer with no pointer")
            }
            
            let paddedSaltSize = salt.count
            let saltBytes = saltPointer.assumingMemoryBound(to: UInt8.self)
            
            var password = password
            let passwordLength = password.count
    
            if passwordLength > chunkSize {
                password = hash.hash(password, count: passwordLength)
            } else if passwordLength < chunkSize {
                password = password + [UInt8](repeating: 0, count: chunkSize - passwordLength)
            }
            
            var outerPadding = [UInt8](repeating: 0x5c, count: chunkSize)
            var innerPadding = [UInt8](repeating: 0x36, count: chunkSize)
            
            func authenticate(message: UnsafePointer<UInt8>, count: Int) -> [UInt8] {
                let innerPaddingHash = hash.hash(message, count: count)
                return hash.hash(bytes: outerPadding + innerPaddingHash)
            }
            
            for i in 0..<passwordLength {
                let byte = password[i]
                
                outerPadding[i] = byte ^ outerPadding[i]
                innerPadding[i] = byte ^ innerPadding[i]
            }
            
            let blocks = UInt32((keySize + digestSize - 1) / digestSize)
            
            for block in 1...blocks {
                saltPointer.advanced(by: saltSize).assumingMemoryBound(to: UInt32.self).pointee = block
                
                var ui = authenticate(message: saltBytes, count: paddedSaltSize)
                var u1 = ui
                
                for _ in 0..<iterations &- 1 {
                    u1 = authenticate(message: u1, count: ui.count)
                    xor(lhs: &ui, rhs: u1)
                }
                
                output.append(contentsOf: ui)
                
                let extra = output.count &- keySize
                
                if extra >= 0 {
                    output.removeLast(extra)
                    return output
                }
            }
            
            return output
        }
    }
}

/// XORs the lhs bytes with the rhs bytes on the same index
///
/// Assumes and asserts lhs and rhs to have an equal count
fileprivate func xor(lhs: inout [UInt8], rhs: [UInt8]) {
    // These two must be equal for the PBKDF2 implementation to be correct
    precondition(lhs.count == rhs.count)
    
    for i in 0..<lhs.count {
        lhs[i] = lhs[i] ^ rhs[i]
    }
}
