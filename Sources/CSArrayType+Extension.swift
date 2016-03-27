//
//  _ArrayType+Extensions.swift
//  CryptoSwift
//
//  Created by Marcin Krzyzanowski on 08/10/15.
//  Copyright © 2015 Marcin Krzyzanowski. All rights reserved.
//

import Foundation

internal protocol CSArrayType: _ArrayProtocol {
    func cs_arrayValue() -> [Generator.Element]
}

extension Array: CSArrayType {
    internal func cs_arrayValue() -> [Iterator.Element] {
        return self
    }
}

internal extension CSArrayType where Iterator.Element == Byte {
    internal func toHexString() -> String {
        return self.lazy.reduce("") { $0 + String(format:"%02x", $1) }
    }
    
    internal func toBase64() -> String? {
        guard let bytesArray = self as? [Byte] else {
            return nil
        }
        
        #if os(Linux)
            return NSData(bytes: bytesArray).base64EncodedStringWithOptions([])
        #else
            return NSData(bytes: bytesArray).base64EncodedString([])
        #endif
    }
    
    internal init(base64: String) {
        self.init()
        
        guard let decodedData = NSData(base64EncodedString: base64, options: []) else {
            return
        }
        
        self.append(contentsOf: decodedData.arrayOfBytes())
    }
}

internal extension CSArrayType where Iterator.Element == Byte {
    
    internal func md5() -> [Iterator.Element] {
        return Hash.md5(cs_arrayValue()).calculate()
    }
    
    internal func sha1() -> [Iterator.Element] {
        return Hash.sha1(cs_arrayValue()).calculate()
    }
}