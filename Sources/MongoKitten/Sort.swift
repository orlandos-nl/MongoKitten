import BSON

public enum SortOrder: ValueConvertible {
    case ascending
    case descending
    case custom(ValueConvertible)
    
    public func makeBSONPrimitive() -> BSONPrimitive {
        switch self {
        case .ascending: return Int32(1)
        case .descending: return Int32(-1)
        case .custom(let value): return value.makeBSONPrimitive()
        }
    }
}

public struct Sort: CustomValueConvertible, ExpressibleByDictionaryLiteral {
    public init?(_ value: BSONPrimitive) {
        guard let document = value as? Document else {
            return nil
        }
        
        self.document = document
    }

    var document: Document
    
    public func makeDocument() -> Document {
        return document
    }

    public func makeBSONPrimitive() -> BSONPrimitive {
        return self.document
    }
    
    public init(dictionaryLiteral elements: (String, SortOrder)...) {
        self.document = Document(dictionaryElements: elements.map {
            ($0.0, $0.1)
        })
    }
    
    public init(_ document: Document) {
        self.document = document
    }
}
