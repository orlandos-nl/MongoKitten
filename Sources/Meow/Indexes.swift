import MongoKitten

public func SortedIndex<M, T>(
    named name: String,
    field: QuerySubject<M, T>,
    order: Sorting.Order = .ascending
) -> _MongoIndex {
    SortedIndex(named: name, field: field.path.string, order: order)
}

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
