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

import Foundation

public protocol ArrayProtocol: RangeReplaceableCollection, ExpressibleByArrayLiteral {
    func arrayValue() -> [Generator.Element]
}

extension Array: ArrayProtocol {
    public func arrayValue() -> [Iterator.Element] {
        return self
    }
}

public extension ArrayProtocol where Iterator.Element == UInt8 {
    public var hexString: String {
        #if os(Linux)
            return self.lazy.reduce("") { $0 + (NSString(format:"%02x", $1).description) }
        #else
            let s = self.lazy.reduce("") { $0 + String(format:"%02x", $1) }
            
            return s
        #endif
    }
    
    public var checksum: UInt16? {
        guard let bytesArray = self as? [UInt8] else {
            return nil
        }
        
        var s:UInt32 = 0
        for i in 0..<bytesArray.count {
            s = s + UInt32(bytesArray[i])
        }
        s = s % 65536
        return UInt16(s)
    }
    
    public var base64: String {
        let bytesArray = self as? [UInt8] ?? []
        
        
        return NSData(bytes: bytesArray).base64EncodedString(options: [])
        
    }
    
    public init(base64: String) {
        self.init()
        
        guard let decodedData = NSData(base64: base64) else {
            return
        }
        
        self.append(contentsOf: decodedData.byteArray)
    }
    
    public init(hexString: String) {
        var data = [UInt8]()
        
        var gen = hexString.characters.makeIterator()
        while let c1 = gen.next(), let c2 = gen.next() {
            let s = String([c1, c2])
            
            guard let d = UInt8(s, radix: 16) else {
                break
            }
            
            data.append(d)
        }
        
        self.init(data)
    }
}

extension Array {
    
    /** split in chunks with given chunk size */
    public func chunks(chunkSize: Int) -> [Array<Element>] {
        var words = [[Element]]()
        words.reserveCapacity(self.count / chunkSize)
        for idx in stride(from: chunkSize, through: self.count, by: chunkSize) {
            let word = Array(self[idx - chunkSize..<idx]) // this is slow for large table
            words.append(word)
        }
        let reminder = Array(self.suffix(self.count % chunkSize))
        if (reminder.count > 0) {
            words.append(reminder)
        }
        return words
    }
}
