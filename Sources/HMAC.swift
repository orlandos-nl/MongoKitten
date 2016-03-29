//
//  HMAC.swift
//  CryptoSwift
//
//  Created by Marcin Krzyzanowski on 13/01/15.
//  Copyright (c) 2015 Marcin Krzyzanowski. All rights reserved.
//

final internal class HMAC {
    
    internal enum Variant {
        case sha1, md5
        
        var size:Int {
            switch (self) {
            case .sha1:
                return SHA1.size
            case .md5:
                return MD5.size
            }
        }
        
        func calculateHash(bytes bytes:[Byte]) -> [Byte]? {
            switch (self) {
            case .sha1:
                return Hash.sha1(bytes).calculate()
            case .md5:
                return Hash.md5(bytes).calculate()
            }
        }
        
        func blockSize() -> Int {
            return 64
        }
    }
    
    var key:[Byte]
    let variant:Variant
    
    class internal func authenticate(key  key: [Byte], message: [Byte], variant:HMAC.Variant = .md5) -> [Byte]? {
        return HMAC(key, variant: variant)?.authenticate(message: message)
    }
    
    // MARK: - Private
    
    internal init? (_ key: [Byte], variant:HMAC.Variant = .md5) {
        self.variant = variant
        self.key = key
        
        if (key.count > variant.blockSize()) {
            if let hash = variant.calculateHash(bytes: key) {
                self.key = hash
            }
        }
        
        if (key.count < variant.blockSize()) { // keys shorter than blocksize are zero-padded
            self.key = key + [Byte](repeating: 0, count: variant.blockSize() - key.count)
        }
    }
    
    internal func authenticate(message  message:[Byte]) -> [Byte]? {
        var opad = [Byte](repeating: 0x5c, count: variant.blockSize())
        for (idx, _) in key.enumerated() {
            opad[idx] = key[idx] ^ opad[idx]
        }
        var ipad = [Byte](repeating: 0x36, count: variant.blockSize())
        for (idx, _) in key.enumerated() {
            ipad[idx] = key[idx] ^ ipad[idx]
        }
        
        var finalHash:[Byte]? = nil;
        if let ipadAndMessageHash = variant.calculateHash(bytes: ipad + message) {
            finalHash = variant.calculateHash(bytes: opad + ipadAndMessageHash);
        }
        return finalHash
    }
}