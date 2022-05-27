import BSON
import MongoKitten

// MARK: Equality

public func == <M: KeyPathQueryableModel, T: Primitive>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path.string == rhs
}

public func == <M: KeyPathQueryableModel, BM>(lhs: QuerySubject<M, Reference<BM>>, rhs: Reference<BM>) -> Document where BM.Identifier: Primitive {
    return lhs.path.string == rhs.reference
}

public func == <M: KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive {
    return lhs.path.string == rhs.rawValue
}

// MARK: Not Equal

public func != <M: KeyPathQueryableModel, T: Primitive>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path.string != rhs
}

public func != <M: KeyPathQueryableModel, BM>(lhs: QuerySubject<M, Reference<BM>>, rhs: Reference<BM>) -> Document where BM.Identifier: Primitive {
    return lhs.path.string != rhs.reference
}

public func != <M: KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive {
    return lhs.path.string != rhs.rawValue
}

// MARK: Comparison

public func <= <M: KeyPathQueryableModel, T: Primitive & Comparable>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path.string <= rhs
}

public func <= <M: KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive & Comparable {
    return lhs.path.string <= rhs.rawValue
}

public func >= <M: KeyPathQueryableModel, T: Primitive & Comparable>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path.string >= rhs
}

public func >= <M: KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive & Comparable {
    return lhs.path.string >= rhs.rawValue
}

public func < <M: KeyPathQueryableModel, T: Primitive & Comparable>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path.string < rhs
}

public func < <M: KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive & Comparable {
    return lhs.path.string < rhs.rawValue
}

public func > <M: KeyPathQueryableModel, T: Primitive & Comparable>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path.string > rhs
}

public func > <M: KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive & Comparable {
    return lhs.path.string > rhs.rawValue
}
