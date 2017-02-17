//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import BSON

internal protocol ValueConvertible : BSONPrimitive {
    func makeBSONPrimitive() -> BSONPrimitive
}

extension ValueConvertible {
    public var typeIdentifier: UInt8 {
        return makeBSONPrimitive().typeIdentifier
    }
    
    public func makeBSONBinary() -> [UInt8] {
        return makeBSONPrimitive().makeBSONBinary()
    }
}
