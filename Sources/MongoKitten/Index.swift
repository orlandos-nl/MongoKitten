import BSON

private struct _CodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        return nil
    }
}

public enum IndexType: Codable {
    fileprivate enum _IndexTypeNames: String, Codable {
        case text
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let order = try? container.decode(SortOrder.self) {
            switch order {
            case .ascending:
                self = .ascending
            case .descending:
                self = .descending
            }
        } else {
            switch try container.decode(_IndexTypeNames.self) {
            case .text:
                self = .text
            }
        }
    }
    
    case ascending, descending
    case text
    
    var primitive: Primitive {
        switch self {
        case .ascending:
            return 1 as Int32
        case .descending:
            return -1 as Int32
        case .text:
            return "text"
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .ascending:
            let value: Int32 = 1
            try container.encode(value)
        case .descending:
            let value: Int32 = -1
            try container.encode(value)
        case .text:
            let value = "text"
            try container.encode(value)
        }
    }
}

public struct IndexKeys: ExpressibleByDictionaryLiteral, Codable, Sequence {
    internal var pairs: [(String, IndexType)]
    
    public init(dictionaryLiteral elements: (String, IndexType)...) {
        self.pairs = elements
    }
    
    public init(pairs: [(String, IndexType)]) {
        self.pairs = pairs
    }
    
    public func encode(to encoder: Encoder) throws {
        var doc = Document()
        
        for (key, order) in pairs {
            doc[key] = order.primitive
        }
        
        try doc.encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _CodingKey.self)
        var pairs = [(String, IndexType)]()
        
        for key in container.allKeys {
            let order = try container.decode(IndexType.self, forKey: key)
            
            pairs.append((key.stringValue, order))
        }
        
        self.pairs = pairs
    }
    
    public func makeIterator() -> IndexingIterator<[(String, IndexType)]> {
        return pairs.makeIterator()
    }
}

public struct Index: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, background, unique, expireAfterSeconds, partialFilterExpression
        case keys = "key"
    }
    
    public var name: String
    public var keys: IndexKeys
    public var partialFilterExpression: Query?
    public var background: Bool?
    public var unique: Bool?
    public var expireAfterSeconds: Int?
    public var weights: [String: Int]?
//    public var collation: Collation?
    
    public init(named name: String, keys: IndexKeys) {
        self.name = name
        self.keys = keys
    }
}
