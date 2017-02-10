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

/// Defines the order in which a field has to be sorted
public enum SortOrder: ValueConvertible {
    /// Ascending means that we order from "past to future" or from "0 to 10"
    case ascending
    
    /// Descending is opposite of ascending
    case descending
    
    /// Custom can be useful for more complex MongoDB behaviour. Generally not used.
    case custom(ValueConvertible)
    
    /// Converts the SortOrder to a BSON primitive for easy embedding
    public func makeBSONPrimitive() -> BSONPrimitive {
        switch self {
        case .ascending: return Int32(1)
        case .descending: return Int32(-1)
        case .custom(let value): return value.makeBSONPrimitive()
        }
    }
}

/// A Sort object specifies to MongoDB in what order certain Documents need to be ordered
///
/// This can be used in normal and aggregate queries
public struct Sort: CustomValueConvertible, ExpressibleByDictionaryLiteral {
    /// Creates a Sort object from a BSONPrimitive
    ///
    /// Only accepts a Document
    public init?(_ value: BSONPrimitive) {
        guard let document = value as? Document else {
            return nil
        }
        
        self.document = document
    }

    /// The underlying Document
    var document: Document
    
    /// Makes this Sort specification a Document
    ///
    /// Technically equal to `makeBSONPrimtive` with the main difference being that the correct type is already available without extraction
    public func makeDocument() -> Document {
        return document
    }

    /// Makes this Sort specification a BSONPrimtive.
    ///
    /// Useful for embedding in a Document
    public func makeBSONPrimitive() -> BSONPrimitive {
        return self.document
    }
    
    /// Initializes a Sort object from a Dictionary literal.
    ///
    /// The key in the Dictionary Literal is the key you want to have sorted.
    ///
    /// The value in the Dictionary Literal is the `SortOrder` you want to use.
    /// (Usually `SortOrder.ascending` or `SortOrder.descending`)
    public init(dictionaryLiteral elements: (String, SortOrder)...) {
        self.document = Document(dictionaryElements: elements.map {
            ($0.0, $0.1)
        })
    }
    
    /// Initializes a custom Sort object from a Document
    public init(_ document: Document) {
        self.document = document
    }
}
