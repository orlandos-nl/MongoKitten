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
public enum SortOrder: Int32 {
    /// Ascending means that we order from "past to future" or from "0 to 10"
    case ascending = 1
    
    /// Descending is opposite of ascending
    case descending = -1
}

/// A Sort object specifies to MongoDB in what order certain Documents need to be ordered
///
/// This can be used in normal and aggregate queries
public struct Sort: DocumentCodable, ExpressibleByDictionaryLiteral {
    /// The underlying Document
    public var document: Document
    
    /// Helper to make mutating/reading sort specifications more accessible
    public subscript(key: String) -> SortOrder? {
        get {
            guard let value = self.document[key] else {
                return nil
            }
            
            switch value {
            case let bool as Bool:
                return bool ? .ascending : .descending
            case let spec as Int32:
                if spec == 1 {
                    return .ascending
                } else if spec == -1 {
                    return .descending
                }
                
                return nil
            default:
                return nil
            }
        }
        set {
            self.document[key] = newValue?.rawValue
        }
    }
    
    /// Initializes a Sort object from a Dictionary literal.
    ///
    /// The key in the Dictionary Literal is the key you want to have sorted.
    ///
    /// The value in the Dictionary Literal is the `SortOrder` you want to use.
    /// (Usually `SortOrder.ascending` or `SortOrder.descending`)
    public init(dictionaryLiteral elements: (String, SortOrder)...) {
        self.document = Document(dictionaryElements: elements.map {
            ($0.0, $0.1.rawValue)
        })
    }
    
    /// Initializes a custom Sort object from a Document
    public init(from document: Document) {
        self.document = document
    }
}
