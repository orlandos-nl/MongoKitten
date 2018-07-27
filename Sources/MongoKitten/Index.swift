import BSON

/// An internal helper that functions as a raw coding key
///
/// Used to read dictionaries dynamically
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

/// All MongoKitten supported index types are listed here.
///
/// WARNING: The set of supported cases may change, do not rely on this
public enum IndexType: Codable {
    /// Used by indexType for type-safety
    private enum _IndexTypeNames: String, Codable {
        case text
    }
    
    /// Used by indexType for type-safety
    private enum _SortOrder: Int32, Codable {
        case ascending = 1
        case descending = -1
    }
    
    /// Decodes the IndexType from the decoder using the above two enums
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let order = try? container.decode(_SortOrder.self) {
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
    
    /// Internal helper that translates the index type to a primitive
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
    
    /// Encodes the index type's primitive to the encoder
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

/// A specification of Index key pairs.
///
/// Can be initializes with a Dictionary-literal and is specified as a String (key) for the field name and IndexType (value) for the type of index applicable to the key.
///
///     let keys: IndexKeys = [
///         "username": .ascending,
///         "description": .text
///     ]
public struct IndexKeys: ExpressibleByDictionaryLiteral, Codable, Sequence {
    internal var pairs: [(String, IndexType)]
    
    /// Initial
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

/// A database index specification.
///
/// Supports sorted indexes including compound indexes. Also has support for text indexes and mutations such as uniqueness.
public struct Index: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, background, unique, expireAfterSeconds, partialFilterExpression, weights
        case keys = "key"
    }
    
    /// The unique index name. If this matches an existing index, this index will overwrite the existing index
    public var name: String
    
    /// All keys to index and how they're indexed
    public var keys: IndexKeys
    
    /// Only documents matching this filter will be indexes
    public var partialFilterExpression: Query?
    
    /// If `true`, this index will be built in the background. This is useful for large datasets
    public var background: Bool?
    
    /// If `true`, all indexed keys are guaranteed to be unique
    public var unique: Bool?
    
    /// If set, all Documents indexed by this index will be removed after the expiration is met
    public var expireAfterSeconds: Int?
    
    public var weights: [String: Int]?
//    public var collation: Collation?
    
    public init(named name: String, keys: IndexKeys) {
        self.name = name
        self.keys = keys
    }
}
