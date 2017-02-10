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

/// A projection removes any keys from it's input Documents that have not been specified to be included except _id.
///
/// If you don't want to include _id you'll have to explicitely not include it.
public struct Projection: CustomValueConvertible {
    /// Initializes this projection from a Document BSONPrimitive
    public init?(_ value: BSONPrimitive) {
        guard let document = value as? Document else {
            return nil
        }
        
        self.document = document
    }

    /// The raw underlying Document of this Projection
    var document: Document
    
    /// Makes this Projection specification a Document
    ///
    /// Technically equal to `makeBSONPrimtive` with the main difference being that the correct type is already available without extraction
    public func makeDocument() -> Document {
        return self.document
    }
    
    /// An expression that can be specified to either include or exclude a field (or some custom value)
    public enum ProjectionExpression: ValueConvertible, ExpressibleByBooleanLiteral, ExpressibleByStringLiteral, ExpressibleByDictionaryLiteral {
        /// Creates a BSONPrimitive of this ProjecitonExpression for easy embedding in Documents
        public func makeBSONPrimitive() -> BSONPrimitive {
            switch self {
            case .custom(let convertible): return convertible.makeBSONPrimitive()
            case .included: return true
            case .excluded: return false
            }
        }
        
        /// A dictionary literal that makes this a custom ProjectionExpression
        public init(stringLiteral value: String) {
            self = .custom(value)
        }
        
        /// A dictionary literal that makes this a custom ProjectionExpression
        public init(unicodeScalarLiteral value: String) {
            self = .custom(value)
        }
        
        /// A dictionary literal that makes this a custom ProjectionExpression
        public init(extendedGraphemeClusterLiteral value: String) {
            self = .custom(value)
        }

        /// A custom projection value
        case custom(ValueConvertible)
        
        /// Includes this field in the projection
        case included
        
        /// Excludes this field from the projection
        case excluded
        
        /// Includes when `true`, Excludes when `false`
        public init(booleanLiteral value: Bool) {
            self = value ? .included : .excluded
        }
        

        /// A dictionary literal that makes this a custom ProjectionExpression
        public init(dictionaryLiteral elements: (StringVariant, ValueConvertible?)...) {
            self = .custom(Document(dictionaryElements: elements))
        }
    }
    
    /// Initializes this projection from a Document
    public init(_ document: Document) {
        self.document = document
    }
    
    /// Supressed the _id key from being included in the projection
    public mutating func suppressIdentifier() {
        document["_id"] = false
    }
    
    /// Creates a BSONPrimitive from this Projection for inclusion in a Document
    public func makeBSONPrimitive() -> BSONPrimitive {
        return self.document
    }
}

extension Projection: ExpressibleByArrayLiteral {
    /// Projection can be initialized with an array of Strings. Each string represents a field that needs to be included.
    public init(arrayLiteral elements: StringVariant...) {
        self.document = Document(dictionaryElements: elements.map {
            return ($0, true)
        }).flattened()
    }
}

extension Projection: ExpressibleByDictionaryLiteral {
    /// Projection can be initialized with a Dictionary. Each key is a String representing a key in the Documents.
    ///
    /// The values are an expression defining whether the key is included, excluded or has a custom value.
    ///
    /// Custom values are rarely used.
    public init(dictionaryLiteral elements: (StringVariant, ProjectionExpression)...) {
        self.document = Document(dictionaryElements: elements.map {
            // FIXME: Mapping as a workarond for the compiler being unable to infer the compliance to a protocol
            ($0.0, $0.1)
        })
    }
}
