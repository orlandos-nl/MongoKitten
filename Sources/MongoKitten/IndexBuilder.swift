import MongoCore
import MongoKittenCore

/// A builder for indexes that can be used in the `createIndex` method
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
    public private(set) var indexes: [CreateIndexes.Index]
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

/// Creates an index with the given name and fields
public func SortedIndex(
    named name: String,
    field: String,
    order: Sorting.Order = .ascending
) -> _MongoIndex {
    // Ascending or descending doesn't matter on one index
    _MongoIndex(index: CreateIndexes.Index(named: name, key: field, order: order))
        .unique()
}

/// Creates an index with the given name and fields that are unique
public func UniqueIndex(
    named name: String,
    field: String,
    order: Sorting.Order = .ascending
) -> _MongoIndex {
    // Ascending or descending doesn't matter on one index
    _MongoIndex(index: CreateIndexes.Index(named: name, key: field, order: order))
        .unique()
}

/// Creates a TTL index with the given name and fields. The `expireAfterSeconds` is the amount of seconds after which the document is removed
public func TTLIndex(
    named name: String,
    field: String,
    expireAfterSeconds seconds: Int
) -> _MongoIndex {
    // Ascending or descending doesn't matter on one index
    _MongoIndex(index: CreateIndexes.Index(named: name, key: field, order: .ascending))
        .ttl(seconds: seconds)
}

/// Creates a text index with the given name and fields. Use this for full-text search queries
/// - SeeAlso: https://docs.mongodb.com/manual/core/index-text/
public func TextScoreIndex(
    named name: String,
    field: String
) -> _MongoIndex {
    // Ascending or descending doesn't matter on one index
    _MongoIndex(index: CreateIndexes.Index(named: name, key: field, order: .textScore))
}
