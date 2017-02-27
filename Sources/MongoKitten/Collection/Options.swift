//
//  Options.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 26/02/2017.
//
//

import BSON

public struct AggregationOptions : ExpressibleByDictionaryLiteral {
    public var fields = [String: Primitive]()
    
    public init(dictionaryLiteral elements: (String, Primitive)...) {
        for pair in elements {
            fields[pair.0] = pair.1
        }
    }
    
    public init(_ dictionary: [String: Primitive]) {
        self.fields = dictionary
    }
}

extension AggregationOptions {
    public static func explain(_ explain: Bool = true) -> AggregationOptions {
        return [
            "explain": explain
        ]
    }
    
    public static func allowDiskUse(_ allowed: Bool = true) -> AggregationOptions {
        return [
            "allowDiskUse": allowed
        ]
    }
    
    public static func bypassDocumentValidation(_ allowed: Bool = true) -> AggregationOptions {
        return [
            "bypassDocumentValidation": allowed
        ]
    }
    
    public static func cursorOptions(_ options: Document) -> AggregationOptions {
        return [
            "cursor": options
        ]
    }
}


public struct InsertOptions : ExpressibleByDictionaryLiteral {
    public var fields = [String: Primitive]()
    
    public init(dictionaryLiteral elements: (String, Primitive)...) {
        for pair in elements {
            fields[pair.0] = pair.1
        }
    }
    
    public init(_ dictionary: [String: Primitive]) {
        self.fields = dictionary
    }
}
