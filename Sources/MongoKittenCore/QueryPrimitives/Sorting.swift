import BSON

public struct Sorting: Encodable, ExpressibleByDictionaryLiteral {
    public enum Order: Encodable {
        case ascending // 1
        case descending // -1
        case textScore // { $meta: "textScore" }
        case custom(Primitive)
        
        public var rawValue: Primitive {
            switch self {
            case .ascending: return 1 as Int32
            case .descending: return -1 as Int32
            case .textScore: return ["$meta": "textScore"] as Document
            case .custom(let primitive): return primitive
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            try self.rawValue.encode(to: encoder)
        }
    }

    
    public var document: Document {
        var doc = Document()

        for (key, value) in spec {
            doc[key] = value.rawValue
        }

        return doc
    }

    private var spec: [(String, Sorting.Order)]

    public init(_ elements: [(String, Sorting.Order)]) {
        self.spec = elements
    }

    public init(dictionaryLiteral elements: (String, Sorting.Order)...) {
        self.init(elements)
    }

    public func encode(to encoder: Encoder) throws {
        try self.document.encode(to: encoder)
    }

    public static func + (lhs: Sorting, rhs: Sorting) -> Sorting {
        return Sorting(lhs.spec + rhs.spec)
    }

    public static func += (lhs: inout Sorting, rhs: Sorting) {
        lhs = lhs + rhs
    }
}
