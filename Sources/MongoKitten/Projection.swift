import BSON

public struct Projection {
    var document: Document
    
    public init(_ document: Document) {
        self.document = document
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
            return ($0, Int32(1))
        }).flattened()
    }
}

extension Projection: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, ValueConvertible)...) {
        self.document = Document(dictionaryElements: elements).flattened()
    }
}
