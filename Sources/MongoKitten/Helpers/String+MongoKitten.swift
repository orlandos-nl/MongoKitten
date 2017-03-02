//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
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
