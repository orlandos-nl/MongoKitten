import BSON

public struct Projection {
    var document: Document
    
    public enum Expression: ValueConvertible {
        case custom(ValueConvertible)
        case included
        case excluded
        
        public func makeBsonValue() -> BSON.Value {
            switch self {
            case .custom(let convertible): return convertible.makeBsonValue()
            case .included: return true
            case .excluded: return false
            }
        }
    }
    
    public init(_ document: Document) {
        self.document = document
    }
    
    public mutating func suppressIdentifier() {
        document["_id"] = false
    }
}

extension Projection: ValueConvertible {
    public func makeBsonValue() -> Value {
        return self.document.makeBsonValue()
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
