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

import MongoCryptoEssentials
import Foundation

final public class HMAC<Variant: HashProtocol> {
    public static func authenticate(message msg:[UInt8], withKey key: [UInt8]) -> [UInt8] {
        var key = key
        
        if (key.count > Variant.size) {
            key = Variant.calculate(key)
        }
        
        if (key.count < Variant.size) { // keys shorter than blocksize are zero-padded
            key = key + [UInt8](repeating: 0, count: Variant.size - key.count)
        }
        
        var opad = [UInt8](repeating: 0x5c, count: Variant.size)
        for (idx, _) in key.enumerated() {
            opad[idx] = key[idx] ^ opad[idx]
        }
        var ipad = [UInt8](repeating: 0x36, count: Variant.size)
        for (idx, _) in key.enumerated() {
            ipad[idx] = key[idx] ^ ipad[idx]
        }
        
        let ipadAndMessageHash = Variant.calculate(ipad + msg)
        let finalHash = Variant.calculate(opad + ipadAndMessageHash);
        
        return finalHash
    }
    
    public static func authenticate(message msg: String, withKey key: [UInt8]) -> [UInt8] {
        return authenticate(message: [UInt8](msg.utf8), withKey: key)
    }
    
    public static func authenticate(message msg: NSData, withKey key: NSData) -> NSData {
        return NSData(bytes: authenticate(message: msg.byteArray, withKey: key.byteArray))
    }
    
    public static func authenticate(message msg: String, withKey key: NSData) -> NSData {
        return NSData(bytes: authenticate(message: [UInt8](msg.utf8), withKey: key.byteArray))
    }
}
