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

    var document: Document
    
    public func makeDocument() -> Document {
        return self.document
    }
    
    ///
    public enum ProjectionExpression: ValueConvertible, ExpressibleByBooleanLiteral, ExpressibleByStringLiteral, ExpressibleByDictionaryLiteral {
        public func makeBSONPrimitive() -> BSONPrimitive {
            switch self {
            case .custom(let convertible): return convertible.makeBSONPrimitive()
            case .included: return true
            case .excluded: return false
            }
        }
        
        public init(stringLiteral value: String) {
            self = .custom(value)
        }
        
        public init(unicodeScalarLiteral value: String) {
            self = .custom(value)
        }
        
        public init(extendedGraphemeClusterLiteral value: String) {
            self = .custom(value)
        }

        case custom(ValueConvertible)
        case included
        case excluded
        
        public init(booleanLiteral value: Bool) {
            self = value ? .included : .excluded
        }
        
        public init(dictionaryLiteral elements: (String, ValueConvertible?)...) {
            self = .custom(Document(dictionaryElements: elements))
        }
    }
    
    public init(_ document: Document) {
        self.document = document
    }
    
    public mutating func suppressIdentifier() {
        document["_id"] = false
    }
    
    public func makeBSONPrimitive() -> BSONPrimitive {
        return self.document
    }
}

extension Projection: ExpressibleByArrayLiteral {
    /// Projection can be initialized with an array of Strings. Each string represents a field that needs to be included.
    public init(arrayLiteral elements: String...) {
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
    public init(dictionaryLiteral elements: (String, ProjectionExpression)...) {
        self.document = Document(dictionaryElements: elements.map {
            // FIXME: Mapping as a workarond for the compiler being unable to infer the compliance to a protocol
            ($0.0, $0.1)
        })
    }
}
