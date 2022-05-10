import BSON
import MongoKitten

#if swift(>=5.1) && os(macOS)
@dynamicMemberLookup
public struct QueryMatcher<M: KeyPathQueryableModel> {
    internal init() {}
    
    public subscript<T>(dynamicMember keyPath: KeyPath<M, T>) -> QuerySubject<M, T> {
        return QuerySubject<M, T>(path:  M.makeFieldPath(forKeyPath: keyPath))
    }
}

public struct QuerySubject<M: KeyPathQueryableModel, T> {
    internal let path: FieldPath
}

public protocol KeyPathQueryableModel: Model {
    static func makeFieldPath<T>(forKeyPath keyPath: KeyPath<Self, T>) -> FieldPath
    static func makePathComponents<T>(forKeyPath keyPath: KeyPath<Self, T>) -> [String]
}

extension KeyPathQueryableModel {
    public static func makeFieldPath<T>(forKeyPath keyPath: KeyPath<Self, T>) -> FieldPath {
        FieldPath(components: makePathComponents(forKeyPath: keyPath))
    }
}

fileprivate struct _DocumentQueryWrapper: MongoKittenQuery {
    fileprivate let document: Document
    
    fileprivate func makeDocument() -> Document {
        return document
    }
}

public func == <M: KeyPathQueryableModel, T: Primitive>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path.string == rhs
}

public func == <M: KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive {
    return lhs.path.string == rhs.rawValue
}

public func != <M: KeyPathQueryableModel, T: Primitive>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path.string != rhs
}

public func != <M: KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive {
    return lhs.path.string != rhs.rawValue
}

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

extension MeowCollection where M: KeyPathQueryableModel {
    public func find(where matching: (QueryMatcher<M>) -> Document) -> MappedCursor<FindQueryBuilder, M> {
        let query = matching(QueryMatcher<M>())
        return self.find(where: query)
    }
}
#endif
