//
//  MAC.swift
//  CryptoSwift
//
//  Created by Marcin Krzyzanowski on 03/09/14.
//  Copyright (c) 2014 Marcin Krzyzanowski. All rights reserved.
//

/**
 *  Message Authentication
 */
public enum Authenticator {
    
    public enum Error: ErrorType {
        case AuthenticateError
    }
    
    /**
     Poly1305
     
     - parameter key: 256-bit key
     */
    case HMAC(key: [UInt8], variant:MongoKitten.HMAC.Variant)
    
    /**
     Generates an authenticator for message using a one-time key and returns the 16-byte result
     
     - returns: 16-byte message authentication code
     */
    public func authenticate(message: [UInt8]) throws -> [UInt8] {
        switch (self) {
        case .HMAC(let key, let variant):
            guard let auth = MongoKitten.HMAC.authenticate(key: key, message: message, variant: variant) else {
                throw Error.AuthenticateError
            }
            return auth
        }
    }
}