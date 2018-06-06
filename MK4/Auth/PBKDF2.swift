import Foundation
import CNIOOpenSSL
import Core

final class PBKDF2 {
    public func hash(
        _ password: Data,
        salt: Data,
        iterations: Int32,
        keySize: Int
    ) throws -> Data {
        let salt = try salt.convertToData()
        
        var output = Data(repeating: 0, count: keySize)
        
        return password.withByteBuffer { passwordBuffer in
            let passwordSize = password.count
            
            return passwordBuffer.baseAddress!.withMemoryRebound(to: Int8.self, capacity: passwordSize) { password in
                return salt.withByteBuffer { saltBuffer in
                    output.withMutableByteBuffer { outputBuffer in
                        let resultCode = PKCS5_PBKDF2_HMAC(
                            password, Int32(passwordSize), // password string and length
                            saltBuffer.baseAddress, Int32(saltBuffer.count), // salt pointer and length
                            iterations, // Iteration count
                            EVP_sha1(), // Algorithm identifier
                            Int32(keySize), outputBuffer.baseAddress // Output buffer
                        )
                        
                        guard resultCode == 1 else {
                            fatalError()
                        }
                    }
                    
                    return output
                }
            }
        }
    }
}

/// XORs the lhs bytes with the rhs bytes on the same index
///
/// Assumes and asserts lhs and rhs to have an equal count
fileprivate func ^=(lhs: inout Data, rhs: Data) {
    // These two must be equal for the PBKDF2 implementation to be correct
    assert(lhs.count == rhs.count)
    
    // Foundation does not guarantee that Data is a top-level blob
    // It may be a sliced blob with a startIndex of > 0
    var lhsIndex = lhs.startIndex
    var rhsIndex = rhs.startIndex
    
    for _ in 0..<lhs.count {
        lhs[lhsIndex] = lhs[lhsIndex] ^ rhs[rhsIndex]
        
        lhsIndex += 1
        rhsIndex += 1
    }
}
