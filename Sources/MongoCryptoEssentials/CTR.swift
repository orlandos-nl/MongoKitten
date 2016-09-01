// Originally based on CryptoSwift by Marcin Krzyżanowski <marcin.krzyzanowski@gmail.com>
// Copyright (C) 2014 Marcin Krzyżanowski <marcin.krzyzanowski@gmail.com>
// This software is provided 'as-is', without any express or implied warranty.
//
// In no event will the authors be held liable for any damages arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
// - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
// - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
// - This notice may not be removed or altered from any source or binary distribution.

// Using testing data from: http://www.inconteam.com/software-development/41-encryption/55-aes-test-vectors
final public class CTR: BlockMode {
    public static let options: BlockModeOptions = [.initializationVectorRequired]
    public static let blockType = InputBlockType.encrypt
    
    public static func makeEncryptionIterator(iv: [UInt8], cipherOperation: @escaping CipherBlockOperation, inputGenerator: AnyIterator<[UInt8]>) -> AnyIterator<[UInt8]> {
        var counter: UInt64 = 0
        
        return AnyIterator {
            guard let plaintext = inputGenerator.next() else {
                return nil
            }
            
            let nonce = buildNonce(iv: iv, counter: counter)
            counter = counter + 1
            if let encrypted = cipherOperation(nonce) {
                return xor(plaintext, encrypted)
            }
            
            return nil
        }
    }
    
    public static func makeDecryptionIterator(iv: [UInt8], cipherOperation: @escaping CipherBlockOperation, inputGenerator: AnyIterator<[UInt8]>) -> AnyIterator<[UInt8]> {
        var counter: UInt64 = 0
        
        return AnyIterator {
            guard let ciphertext = inputGenerator.next() else {
                return nil
            }
            
            let nonce = buildNonce(iv: iv, counter: counter)
            counter = counter + 1
            
            if let decrypted = cipherOperation(nonce) {
                return xor(decrypted, ciphertext)
            }
            
            return nil
        }
    }
    
    private static func buildNonce(iv: [UInt8], counter: UInt64) -> [UInt8] {
        let noncePartLen = 16 / 2
        let noncePrefix = Array(iv[0..<noncePartLen])
        let nonceSuffix = Array(iv[noncePartLen..<iv.count])
        let c = UInt64.makeInteger(with: nonceSuffix) + counter
        return noncePrefix + arrayOfBytes(c)
    }
}
