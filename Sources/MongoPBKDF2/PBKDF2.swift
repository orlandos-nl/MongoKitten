//
//  PBKDF2.swift
//  CryptoKitten
//
//  Created by Joannis Orlandos on 29/03/16.
//
//

import MongoHMAC
import MongoCryptoEssentials
import Foundation

public enum PBKDF2Error: Error {
    case invalidInput
}

public final class PBKDF2<Variant: HashProtocol> {
    /// Used for applying an HMAC variant on a password and salt
    private static func digest(_ password: [UInt8], data: [UInt8]) throws -> [UInt8] {
        return HMAC<Variant>.authenticate(message: data, withKey: password)
    }
    
    /// Used to make the block number
    /// Credit to Marcin Krzyzanowski
    private static func blockNumSaltThing(blockNum block: UInt) -> [UInt8] {
        var inti = [UInt8](repeating: 0, count: 4)
        inti[0] = UInt8((block >> 24) & 0xFF)
        inti[1] = UInt8((block >> 16) & 0xFF)
        inti[2] = UInt8((block >> 8) & 0xFF)
        inti[3] = UInt8(block & 0xFF)
        return inti
    }
    
    /// Applies the `hi` (PBKDF2 with HMAC as PseudoRandom Function)
    public static func calculate(_ password: [UInt8], usingSalt salt: [UInt8], iterating iterations: Int, keySize: Int? = nil) throws -> [UInt8] {
        let keySize = keySize ?? Variant.size
        guard iterations > 0 && password.count > 0 && salt.count > 0 && keySize <= Int(((pow(2,32) as Double) - 1) * Double(Variant.size)) else {
            throw PBKDF2Error.invalidInput
        }
        
        let blocks = UInt(ceil(Double(keySize) / Double(Variant.size)))
        var response = [UInt8]()
        
        for block in 1...blocks {
            var s = salt
            s.append(contentsOf: self.blockNumSaltThing(blockNum: block))
            
            var ui = try digest(password, data: s)
            var u1 = ui
            
            for _ in 0..<iterations - 1 {
                u1 = try digest(password, data: u1)
                ui = xor(ui, u1)
            }
            
            response.append(contentsOf: ui)
        }
        
        return response
    }
    
    /// Applies the `hi` (PBKDF2 with HMAC as PseudoRandom Function)
    public static func calculate(_ password: String, usingSalt salt: [UInt8], iterating iterations: Int, keySize: Int? = nil) throws -> [UInt8] {
        return try self.calculate([UInt8](password.utf8), usingSalt: salt, iterating: iterations, keySize: keySize)
    }
}
