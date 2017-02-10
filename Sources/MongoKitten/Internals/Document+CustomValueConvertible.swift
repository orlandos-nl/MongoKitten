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

/// CustomValueConvertible allows an object to be converted to a BSONPrimitive but also requires a conversion back using an initializer.
public protocol CustomValueConvertible: ValueConvertible {
    /// Initializes this object from a `BSONPrimitive`
    init?(_ value: BSONPrimitive)
}

extension Document {
    /// Extracts a CustomValueConvertible located at the given key, if possible
    public func extract<V: CustomValueConvertible>(_ key: SubscriptExpressionType...) -> V? {
        guard let primitive = self[raw: key]?.makeBSONPrimitive() else {
            return nil
        }
        
        return V(primitive)
    }
    
    /// Extracts a CustomValueConvertible located at the given key, if possible
    public func extract<V: CustomValueConvertible>(_ key: [SubscriptExpressionType]) -> V? {
        guard let primitive = self[raw: key]?.makeBSONPrimitive() else {
            return nil
        }
        
        return V(primitive)
    }
    
    /// Updates a CustomValueConvertible located at the given key
    public mutating func updateValue<V: CustomValueConvertible>(_ value: V?, forKey key: SubscriptExpressionType...) {
        self[raw: key] = value
    }
    
    /// Updates a CustomValueConvertible located at the given key
    public mutating func updateValue<V: CustomValueConvertible>(_ value: V?, forKey key: [SubscriptExpressionType]) {
        self[raw: key] = value
    }
}
