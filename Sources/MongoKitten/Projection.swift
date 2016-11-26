import BSON

public struct Projection: CustomValueConvertible, DocumentRepresentable {
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
    
    public enum Expression: ValueConvertible, ExpressibleByBooleanLiteral {
        public func makeBSONPrimitive() -> BSONPrimitive {
            switch self {
            case .custom(let convertible): return convertible.makeBSONPrimitive()
            case .included: return true
            case .excluded: return false
            }
        }

        case custom(ValueConvertible)
        case included
        case excluded
        
        public init(booleanLiteral value: Bool) {
            self = value ? .included : .excluded
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
    public init(arrayLiteral elements: String...) {
        self.document = Document(dictionaryElements: elements.map {
            return ($0, true)
        }).flattened()
    }
}

extension Projection: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Expression)...) {
        self.document = Document(dictionaryElements: elements.map {
            // FIXME: Mapping as a workarond for the compiler being unable to infer the compliance to a protocol
            ($0.0, $0.1)
        }).flattened()
    }
}
