import CNIOOpenSSL
import Foundation

final class Hash {
    var evp: UnsafePointer<EVP_MD>
    var ctx = EVP_MD_CTX_create()!
    
    init(evp: UnsafePointer<EVP_MD>) {
        self.evp = evp
        
        EVP_DigestInit_ex(ctx, evp, nil)
    }
    
    @discardableResult
    func update(_ data: Data) -> Hash {
        data.withByteBuffer { buffer in
            _ = EVP_DigestUpdate(ctx, buffer.baseAddress, numericCast(buffer.count))
        }
        
        return self
    }
    
    @discardableResult
    func update(_ string: String) -> Hash {
        let characters = [UInt8](string.utf8)
        
        // Don't hash the null terminator
        characters.withUnsafeBytes { characters in
            _ = EVP_DigestUpdate(ctx, characters.baseAddress, characters.count)
        }
        
        return self
    }
    
    func finalize() -> Data {
        var hash = Data(repeating: 0, count: Int(EVP_MAX_MD_SIZE))
        var count: UInt32 = 0
        
        hash.withMutableByteBuffer { buffer in
            _ = EVP_DigestFinal(ctx, buffer.baseAddress, &count)
        }
        
        hash.removeLast(hash.count - numericCast(count))
        
        return hash
    }
    
    deinit { EVP_MD_CTX_destroy(ctx) }
}

func MD5() -> Hash {
    return Hash(evp: EVP_md5())
}

func SHA1() -> Hash {
    return Hash(evp: EVP_sha1())
}

func HMAC_SHA1(_ message: Data, withKey key: Data) -> Data {
    var ctx = HMAC_CTX()
    
    key.withByteBuffer { buffer in
        _ = HMAC_Init_ex(&ctx, buffer.baseAddress, numericCast(buffer.count), EVP_sha1(), nil)
    }
    
    message.withByteBuffer { buffer in
        _ = HMAC_Update(&ctx, buffer.baseAddress, numericCast(buffer.count))
    }
    
    var hash = Data(repeating: 0, count: Int(EVP_MAX_MD_SIZE))
    var count: UInt32 = 0
    
    hash.withMutableByteBuffer { buffer in
        _ = HMAC_Final(&ctx, buffer.baseAddress, &count)
    }
    
    hash.removeLast(hash.count - numericCast(count))
    
    HMAC_CTX_cleanup(&ctx)
    
    return hash
}
