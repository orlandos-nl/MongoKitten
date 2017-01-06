//
//  String+MongoKitten.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 06/01/2017.
//
//

import Foundation

extension String {
    /// This `String` as c-string
    internal var cStringBytes : [UInt8] {
        var byteArray = self.utf8.filter{$0 != 0x00}
        byteArray.append(0x00)

        return byteArray
    }
}
