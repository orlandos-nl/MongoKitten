import BSON

public struct Projection {
    public fileprivate(set) var document: Document
    
    public init(_ document: Document) {
        self.document = document
    }
}

extension Projection: ValueConvertible {
    public func makeBsonValue() -> Value {
        return ~self.document
    }
}

extension Projection: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: String...) {
        self.document = Document(dictionaryElements: elements.map {
            return ($0, .int32(1))
        }).flattened()
    }
}

extension Projection: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Value)...) {
        self.document = Document(dictionaryElements: elements).flattened()
    }
}
