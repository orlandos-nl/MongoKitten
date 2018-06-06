//
//  Options.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 26/02/2017.
//
//

import BSON

/// An option to use for an aggregate operation
public struct AggregationOptions : ExpressibleByDictionaryLiteral {
    /// The fields to apply to the command document
    public var fields = [String: Primitive]()
    
    /// Allows initialization from a Dictionary Literal
    public init(dictionaryLiteral elements: (String, Primitive)...) {
        for pair in elements {
            fields[pair.0] = pair.1
        }
    }
    
    /// Allows initialization like a Dictionary
    public init(_ dictionary: [String: Primitive]) {
        self.fields = dictionary
    }
}

extension AggregationOptions {
    /// Explains the operation
    public static func explain(_ explain: Bool = true) -> AggregationOptions {
        return [
            "explain": explain
        ]
    }
    
    /// Allow using the disk
    public static func allowDiskUse(_ allowed: Bool = true) -> AggregationOptions {
        return [
            "allowDiskUse": allowed
        ]
    }
    
    /// Bypasses Document validation
    public static func bypassDocumentValidation(_ allowed: Bool = true) -> AggregationOptions {
        return [
            "bypassDocumentValidation": allowed
        ]
    }
    
    /// Special options for the cursor
    public static func cursorOptions(_ options: Document) -> AggregationOptions {
        return [
            "cursor": options
        ]
    }
}
