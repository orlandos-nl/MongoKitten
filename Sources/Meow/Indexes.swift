import MongoKitten

/// Creates an index on the specified `field`. Allows faster lookups for queries targetting this field.
/// Useful for optimising commonly queries fields, especially in large datasets, and allows for faster sorting on this field.
///
/// ```swift
/// meow[User.self].buildIndexes { user in
///     SortedIndex(named: "sort-createdAt", field: user.$createdAt)
/// }
/// ```
public func SortedIndex<M, T>(
    named name: String,
    field: QuerySubject<M, T>,
    order: Sorting.Order = .ascending
) -> _MongoIndex {
    SortedIndex(named: name, field: field.path.string, order: order)
}

/// Creates an index with uniqueness on the specified `field`. Allows faster lookups for queries targetting this field.
/// Useful for optimising commonly queries fields, especially in large datasets, and allows for faster sorting on this field.
///
/// ```swift
/// meow[User.self].buildIndexes { user in
///     UniqueIndex(named: "unique-username", field: user.$username)
/// }
/// ```
public func UniqueIndex<M, T>(
    named name: String,
    field: QuerySubject<M, T>,
    order: Sorting.Order = .ascending
) -> _MongoIndex {
    UniqueIndex(named: name, field: field.path.string, order: order)
}

public func TTLIndex<M, T>(
    named name: String,
    field: QuerySubject<M, T>,
    expireAfterSeconds seconds: Int
) -> _MongoIndex {
    TTLIndex(named: name, field: field.path.string, expireAfterSeconds: seconds)
}

public func TextScoreIndex<M, T>(
    named name: String,
    field: QuerySubject<M, T>
) -> _MongoIndex {
    TextScoreIndex(named: name, field: field.path.string)
}
