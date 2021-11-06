import MongoCore
import MongoKittenCore

#if swift(>=5.3)
@resultBuilder
public struct MongoIndexBuilder {
    public static func buildBlock() -> _MongoIndexes {
        return _MongoIndexes(indexes: [])
    }
    
    public static func buildBlock(_ content: _MongoIndex) -> _MongoIndexes {
        .init(indexes: [content.index])
    }
    
    public static func buildBlock(_ content: _MongoIndex...) -> _MongoIndexes {
        return _MongoIndexes(indexes: content.reduce([], { $0 + [$1.index] }))
    }
    
    public static func buildIf(_ content: _MongoIndex?) -> _MongoIndexes {
        if let content = content {
            return .init(indexes: [content.index])
        }
        
        return _MongoIndexes(indexes: [])
    }
    
    public static func buildEither(first: _MongoIndex) -> _MongoIndexes {
        .init(indexes: [first.index])
    }
    
    public static func buildEither(second: _MongoIndex) -> _MongoIndexes {
        .init(indexes: [second.index])
    }
}

public struct _MongoIndexes {
    internal var indexes: [CreateIndexes.Index]
}

public struct _MongoIndex {
    internal var index: CreateIndexes.Index
    
    public func unique(_ isUnique: Bool = true) -> _MongoIndex {
        var copy = self
        copy.index.unique = isUnique
        return copy
    }
    
    /// Apply this on date fields
    /// `nil` unsets the TTL on this index
    public func ttl(seconds: Int?) -> _MongoIndex {
        var copy = self
        copy.index.expireAfterSeconds = seconds
        return copy
    }
    
    public func collation(_ collation: Collation?) -> _MongoIndex {
        var copy = self
        copy.index.collation = collation
        return copy
    }
}

public func SortedIndex(
    named name: String,
    field: String,
    order: SortOrder = .ascending
) -> _MongoIndex {
    // Ascending or descending doesn't matter on one index
    _MongoIndex(index: CreateIndexes.Index(named: name, key: field, order: order))
        .unique()
}

public func UniqueIndex(
    named name: String,
    field: String,
    order: SortOrder = .ascending
) -> _MongoIndex {
    // Ascending or descending doesn't matter on one index
    _MongoIndex(index: CreateIndexes.Index(named: name, key: field, order: order))
        .unique()
}

public func TTLIndex(
    named name: String,
    field: String,
    expireAfterSeconds seconds: Int
) -> _MongoIndex {
    // Ascending or descending doesn't matter on one index
    _MongoIndex(index: CreateIndexes.Index(named: name, key: field, order: .ascending))
        .ttl(seconds: seconds)
}

public func TextScoreIndex(
    named name: String,
    field: String
) -> _MongoIndex {
    // Ascending or descending doesn't matter on one index
    _MongoIndex(index: CreateIndexes.Index(named: name, key: field, order: .textScore))
}
#endif
