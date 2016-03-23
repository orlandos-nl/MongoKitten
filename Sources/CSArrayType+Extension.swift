//
//  _ArrayType+Extensions.swift
//  CryptoSwift
//
//  Created by Marcin Krzyzanowski on 08/10/15.
//  Copyright © 2015 Marcin Krzyzanowski. All rights reserved.
//

import Foundation

public protocol CSArrayType: _ArrayType {
    func cs_arrayValue() -> [Generator.Element]
}

extension Array: CSArrayType {
    public func cs_arrayValue() -> [Generator.Element] {
        return self
    }
}

public extension CSArrayType where Generator.Element == UInt8 {
    public func toHexString() -> String {
        return self.lazy.reduce("") { $0 + String(format:"%02x", $1) }
    }
    
    public func toBase64() -> String? {
        guard let bytesArray = self as? [UInt8] else {
            return nil
        }
        
        return NSData(bytes: bytesArray).base64EncodedStringWithOptions([])
    }
    
    public init(base64: String) {
        self.init()
        
        guard let decodedData = NSData(base64EncodedString: base64, options: []) else {
            return
        }
        
        self.appendContentsOf(decodedData.arrayOfBytes())
    }
}

public extension CSArrayType where Generator.Element == UInt8 {
    
    public func md5() -> [Generator.Element] {
        return Hash.md5(cs_arrayValue()).calculate()
    }
    
    public func sha1() -> [Generator.Element] {
        return Hash.sha1(cs_arrayValue()).calculate()
    }
}