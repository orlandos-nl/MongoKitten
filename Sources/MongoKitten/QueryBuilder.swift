import BSON

public func ==(lhs: String, rhs: Primitive?) -> Document {
    return [
        lhs: [
            "$eq": rhs ?? Null()
        ] as Document
    ]
}

public func !=(lhs: String, rhs: Primitive?) -> Document {
    return [
        lhs: [
            "$ne": rhs ?? Null()
        ] as Document
    ]
}

public prefix func !(rhs: Primitive?) -> Document {
    return [
        "$not": rhs ?? Null()
    ]
}

public func > (lhs: String, rhs: Primitive) -> Document {
    return [
        lhs: [
            "$gt": rhs
        ] as Document
    ]
}

public func < (lhs: String, rhs: Primitive) -> Document {
    return [
        lhs: [
            "$lt": rhs
        ] as Document
    ]
}

public func >= (lhs: String, rhs: Primitive) -> Document {
    return [
        lhs: [
            "$gte": rhs
        ] as Document
    ]
}

public func <= (lhs: String, rhs: Primitive) -> Document {
    return [
        lhs: [
            "$lte": rhs
        ] as Document
    ]
}

public protocol MongoKittenQuery {
    func makeDocument() -> Document
}

public struct AndQuery: MongoKittenQuery {
    private enum CodingKeys: String, CodingKey {
        case conditions = "$and"
    }
    
    public var conditions: [Document]
    
    public init(conditions: [Document]) {
        self.conditions = conditions
    }
    
    public func makeDocument() -> Document {
        return ["$and": Document(array: conditions)]
    }
}

public func && (lhs: AndQuery, rhs: MongoKittenQuery) -> AndQuery {
    return AndQuery(conditions: lhs.conditions + [rhs.makeDocument()])
}

public func && (lhs: MongoKittenQuery, rhs: AndQuery) -> AndQuery {
    return AndQuery(conditions: [lhs.makeDocument()] + rhs.conditions)
}

public func && (lhs: AndQuery, rhs: AndQuery) -> AndQuery {
    return AndQuery(conditions: lhs.conditions + rhs.conditions)
}

public func && (lhs: MongoKittenQuery, rhs: MongoKittenQuery) -> AndQuery {
    return AndQuery(conditions: [lhs.makeDocument(), rhs.makeDocument()])
}

public func && (lhs: Document, rhs: MongoKittenQuery) -> AndQuery {
    return AndQuery(conditions: [lhs, rhs.makeDocument()])
}

public func && (lhs: MongoKittenQuery, rhs: Document) -> AndQuery {
    return AndQuery(conditions: [lhs.makeDocument(), rhs])
}

public func && (lhs: Document, rhs: Document) -> AndQuery {
    return AndQuery(conditions: [lhs, rhs])
}

public func && (lhs: AndQuery, rhs: Document) -> AndQuery {
    return AndQuery(conditions: lhs.conditions + [rhs])
}

public func && (lhs: Document, rhs: AndQuery) -> AndQuery {
    return AndQuery(conditions: [lhs] + rhs.conditions)
}

public struct OrQuery: MongoKittenQuery {
    private enum CodingKeys: String, CodingKey {
        case conditions = "$or"
    }
    
    public var conditions: [Document]
    
    public init(conditions: [Document]) {
        self.conditions = conditions
    }
    
    public func makeDocument() -> Document {
        return ["$or": Document(array: conditions)]
    }
}

public func || (lhs: OrQuery, rhs: MongoKittenQuery) -> OrQuery {
    return OrQuery(conditions: lhs.conditions + [rhs.makeDocument()])
}

public func || (lhs: MongoKittenQuery, rhs: OrQuery) -> OrQuery {
    return OrQuery(conditions: [lhs.makeDocument()] + rhs.conditions)
}

public func || (lhs: OrQuery, rhs: OrQuery) -> OrQuery {
    return OrQuery(conditions: lhs.conditions + rhs.conditions)
}

public func || (lhs: MongoKittenQuery, rhs: MongoKittenQuery) -> OrQuery {
    return OrQuery(conditions: [lhs.makeDocument(), rhs.makeDocument()])
}

public func || (lhs: Document, rhs: MongoKittenQuery) -> OrQuery {
    return OrQuery(conditions: [lhs, rhs.makeDocument()])
}

public func || (lhs: MongoKittenQuery, rhs: Document) -> OrQuery {
    return OrQuery(conditions: [lhs.makeDocument(), rhs])
}

public func || (lhs: Document, rhs: Document) -> OrQuery {
    return OrQuery(conditions: [lhs, rhs])
}

public func || (lhs: OrQuery, rhs: Document) -> OrQuery {
    return OrQuery(conditions: lhs.conditions + [rhs])
}

public func || (lhs: Document, rhs: OrQuery) -> OrQuery {
    return OrQuery(conditions: [lhs] + rhs.conditions)
}
