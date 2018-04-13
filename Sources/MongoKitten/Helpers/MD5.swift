import CNIOOpenSSL
import Foundation

struct MD5 {
    var md5: UnsafePointer<EVP_MD>
    init() {
        self.md5 = EVP_md5()
    }
    
    @discardableResult
    func update(_ data: Data) -> MD5 {
        data.withMutableByteBuffer { buffer in
            EVP_DigestUpdate(&md5, buffer.baseAddress, buffer.count)
        }
        
        return self
    }
    
    @discardableResult
    func update(_ string: String) -> MD5 {
        let characters = [UInt8](string.utf8)
        
        // Don't hash the null terminator
        EVP_DigestUpdate(&md5, &characters, characters.count)
        
        return self
    }
    
    func finalize() -> Data {
        var hash = Data(repeating: 0, count: Int(EVP_MAX_MD_SIZE))
        var count: UInt32 = 0
        
        hash.withMutableByteBuffer { buffer in
            EVP_DigestFinal(&md5, buffer.baseAddress, &count)
        }
        
        hash.removeLast(data.count - numericCast(count))
        
        return hash
    }
}
