import BSON
import MongoKitten

// MARK: Equality

public func == <M: KeyPathQueryableModel, T: Primitive>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path.string == rhs
}

public func == <C: QuerySubjectComparator>(lhs: C, rhs: C.Value) -> Document {
    return lhs.path.string == rhs
}

public func == <M: KeyPathQueryableModel, BM>(lhs: QuerySubject<M, Reference<BM>>, rhs: Reference<BM>) -> Document where BM.Identifier: Primitive {
    return lhs.path.string == rhs.reference
}

public func == <M: KeyPathQueryableModel, BM>(lhs: QuerySubject<M, Reference<BM>>, rhs: BM.Identifier) -> Document where BM.Identifier: Primitive {
    return lhs.path.string == rhs
}

public func == <M: KeyPathQueryableModel, BM>(lhs: QuerySubject<M, Reference<BM>>, rhs: BM.Identifier) throws -> Document {
    let rhs = try rhs.encodePrimitive()
    return lhs.path.string == rhs
}

public func == <M: KeyPathQueryableModel>(lhs: QuerySubject<M, M.Identifier>, rhs: Reference<M>) -> Document where M.Identifier: Primitive {
    return lhs.path.string == rhs.reference
}

public func == <M: KeyPathQueryableModel>(lhs: QuerySubject<M, M.Identifier>, rhs: Reference<M>) throws -> Document {
    let rhs = try rhs.reference.encodePrimitive()
    return lhs.path.string == rhs
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

public func <= <C: QuerySubjectComparator>(lhs: C, rhs: C.Value) -> Document {
    return lhs.path.string <= rhs
}

public func >= <M: KeyPathQueryableModel, T: Primitive & Comparable>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path.string >= rhs
}

public func >= <M: KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive & Comparable {
    return lhs.path.string >= rhs.rawValue
}

public func >= <C: QuerySubjectComparator>(lhs: C, rhs: C.Value) -> Document {
    return lhs.path.string >= rhs
}

public func < <M: KeyPathQueryableModel, T: Primitive & Comparable>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path.string < rhs
}

public func < <M: KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive & Comparable {
    return lhs.path.string < rhs.rawValue
}

public func < <C: QuerySubjectComparator>(lhs: C, rhs: C.Value) -> Document {
    return lhs.path.string < rhs
}

public func > <M: KeyPathQueryableModel, T: Primitive & Comparable>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path.string > rhs
}

public func > <M: KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive & Comparable {
    return lhs.path.string > rhs.rawValue
}

public func > <C: QuerySubjectComparator>(lhs: C, rhs: C.Value) -> Document {
    return lhs.path.string > rhs
}
