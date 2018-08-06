import Foundation

/// The requested amount of output bytes from the key derivation
///
/// In circumstances with low iterations the amount of output bytes may not be met.
///
/// `digest.digestSize * iterations` is the amount of bytes stored in PBKDF2's buffer.
/// Any data added beyond this limit
///
/// WARNING: Do not switch these key sizes, new sizes may be added
public enum PBKDF2KeySize: ExpressibleByIntegerLiteral {
    case digestSize
    case fixed(Int)
    
    public init(integerLiteral value: Int) {
        self = .fixed(value)
    }
    
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
        
        var password = password
        
        if password.count > chunkSize {
            password = hash.hash(password, count: password.count)
        }
        
        if password.count < chunkSize {
            password = password + [UInt8](repeating: 0, count: chunkSize - password.count)
        }
        
        var outerPadding = [UInt8](repeating: 0x5c, count: chunkSize)
        var innerPadding = [UInt8](repeating: 0x36, count: chunkSize)
        
        xor(&innerPadding, password)
        xor(&outerPadding, password)
        
        func authenticate(message: [UInt8]) -> [UInt8] {
            let innerPaddingHash = hash.hash(bytes: innerPadding + message)
            return hash.hash(bytes: outerPadding + innerPaddingHash)
        }
        
        var output = [UInt8]()
        output.reserveCapacity(keySize)
        
        func calculate(block: UInt32) {
            salt.withUnsafeMutableBytes { salt in
                salt.baseAddress!.advanced(by: saltSize).assumingMemoryBound(to: UInt32.self).pointee = block.bigEndian
            }
            
            var ui = authenticate(message: salt)
            var u1 = ui
            
            if iterations > 1 {
                for _ in 1..<iterations {
                    ui = authenticate(message: ui)
                    xor(&u1, ui)
                }
            }
            
            output.append(contentsOf: u1)
        }
        
        for block in 1...UInt32((keySize + digestSize - 1) / digestSize) {
            calculate(block: block)
        }
        
        let extra = output.count &- keySize
        
        if extra >= 0 {
            output.removeLast(extra)
            return output
        }
        
        return output
    }
}

/// XORs the lhs bytes with the rhs bytes on the same index
///
/// Requires lhs and rhs to have an equal count
public func xor(_ lhs: inout [UInt8], _ rhs: [UInt8]) {
    // These two must be equal for the PBKDF2 implementation to be correct
    precondition(lhs.count == rhs.count)
    
    for i in 0..<lhs.count {
        lhs[i] = lhs[i] ^ rhs[i]
    }
}
