import BSON

public enum SortOrder: ValueConvertible {
    case ascending
    case descending
    case custom(ValueConvertible)
    
    public func makeBsonValue() -> Value {
        switch self {
            case .ascending: return .int32(1)
            case .descending: return .int32(-1)
            case .custom(let value): return value.makeBsonValue()
        }
    }
}

public struct Sort: ValueConvertible, ExpressibleByDictionaryLiteral {
    var document: Document

    public func makeBsonValue() -> Value {
        return document.makeBsonValue()
    }
    
    public init(dictionaryLiteral elements: (String, SortOrder)...) {
        self.document = Document(dictionaryElements: elements.map {
            ($0.0, $0.1.makeBsonValue())
        })
    }
    
    public init(_ document: Document) {
        self.document = document
    }
}
