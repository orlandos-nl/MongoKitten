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

internal protocol ValueConvertible : BSON.Primitive {
    func makePrimitive() -> BSON.Primitive
}

extension ValueConvertible {
    
    public var typeIdentifier: Byte {
        return makePrimitive().typeIdentifier
    }
    
    public func makeBinary() -> Bytes {
        return makePrimitive().makeBinary()
    }
}
