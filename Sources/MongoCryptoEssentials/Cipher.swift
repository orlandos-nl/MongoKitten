//
//  Cipher.swift
//  CryptoKitten
//
//  Created by Joannis Orlandos on 29/04/16.
//
//

public protocol Cipher {
    
}

public protocol BlockCipher : Cipher {
    associatedtype Mode: BlockMode
}