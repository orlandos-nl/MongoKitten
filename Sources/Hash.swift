//
//  CryptoHash.swift
//  CryptoSwift
//
//  Created by Marcin Krzyzanowski on 07/08/14.
//  Copyright (c) 2014 Marcin Krzyzanowski. All rights reserved.
//

public enum Hash {
    case md5(Array<Byte>)
    case sha1(Array<Byte>)
    
    public func calculate() -> [Byte] {
        switch self {
        case md5(let bytes):
            return MD5(bytes).calculate()
        case sha1(let bytes):
            return SHA1(bytes).calculate()
        }
    }
}