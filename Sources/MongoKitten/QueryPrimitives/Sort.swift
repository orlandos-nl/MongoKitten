import BSON

public enum SortOrder: Encodable {
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

public struct Sort: Encodable, ExpressibleByDictionaryLiteral {
    public var document: Document {
        var doc = Document()

        for (key, value) in spec {
            doc[key] = value.rawValue
        }

        return doc
    }

    private var spec: [(String, SortOrder)]

    public init(_ elements: [(String, SortOrder)]) {
        self.spec = elements
    }

    public init(dictionaryLiteral elements: (String, SortOrder)...) {
        self.init(elements)
    }

    public func encode(to encoder: Encoder) throws {
        try self.document.encode(to: encoder)
    }

    public static func + (lhs: Sort, rhs: Sort) -> Sort {
        return Sort(lhs.spec + rhs.spec)
    }

    public static func += (lhs: inout Sort, rhs: Sort) {
        lhs = lhs + rhs
    }
}
