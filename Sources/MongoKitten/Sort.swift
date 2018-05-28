public enum SortOrder: Int32, Encodable {
    case ascending = 1
    case descending = -1
}

public struct Sort: Encodable, ExpressibleByDictionaryLiteral {
    var document: Document {
        var doc = Document()
        
        for (key, value) in spec {
            doc[key] = value.rawValue
        }
        
        return doc
    }
    
    private var spec: [(String, SortOrder)]
    
    public init(dictionaryLiteral elements: (String, SortOrder)...) {
        self.spec = elements
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.document.encode(to: encoder)
    }
}
