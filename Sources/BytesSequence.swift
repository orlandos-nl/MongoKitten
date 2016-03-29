//
//  BytesSequence.swift
//  CryptoSwift
//
//  Created by Marcin Krzyzanowski on 26/09/15.
//  Copyright © 2015 Marcin Krzyzanowski. All rights reserved.
//

import Foundation

//TODO: func anyGenerator is renamed to AnyGenerator in Swift 2.2, until then it's just dirty hack for linux (because swift >= 2.2 is available for Linux)
private func CS_AnyGenerator<Element>(body: () -> Element?) -> AnyIterator<Element> {
    return AnyIterator(body: body)
}

struct BytesSequence: Sequence {
    let chunkSize: Int
    let data: [Byte]
    
    func makeIterator() -> AnyIterator<ArraySlice<Byte>> {
        
        var offset:Int = 0
        
        return CS_AnyGenerator {
            let end = Swift.min(self.chunkSize, self.data.count - offset)
            let result = self.data[offset..<offset + end]
            offset += result.count
            return result.count > 0 ? result : nil
        }
    }
}