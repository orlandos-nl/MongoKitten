import BSON
import MongoKitten

#if swift(>=5.1) && os(macOS)
@dynamicMemberLookup
public struct QueryMatcher<M: _KeyPathQueryableModel> {
    internal init() {}
    
    public subscript<T>(dynamicMember keyPath: KeyPath<M, T>) -> QuerySubject<M, T> {
        let path = M.makePathComponents(forKeyPath: keyPath).joined(separator: ".")
        return QuerySubject<M, T>(path: path)
    }
}

public struct QuerySubject<M: _KeyPathQueryableModel, T> {
    internal let path: String
}

public protocol _KeyPathQueryableModel: _Model {
    static func makePathComponents<T>(forKeyPath keyPath: KeyPath<Self, T>) -> [String]
}

public protocol KeyPathQueryableModel: _KeyPathQueryableModel, Model {
    static func makePathComponents<T>(forKeyPath keyPath: KeyPath<Self, T>) -> [String]
}

public protocol KeyPathQueryableSuperModel: _KeyPathQueryableModel, SuperModel {
    static func makePathComponents<T>(forKeyPath keyPath: KeyPath<Self, T>) -> [String]
}

fileprivate struct _DocumentQueryWrapper: MongoKittenQuery {
    fileprivate let document: Document
    
    fileprivate func makeDocument() -> Document {
        return document
    }
}

public func == <M: _KeyPathQueryableModel, T: Primitive>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path == rhs
}

public func == <M: _KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive {
    return lhs.path == rhs.rawValue
}

public func != <M: _KeyPathQueryableModel, T: Primitive>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path != rhs
}

public func != <M: _KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive {
    return lhs.path != rhs.rawValue
}

public func <= <M: _KeyPathQueryableModel, T: Primitive & Comparable>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path <= rhs
}

public func <= <M: _KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive & Comparable {
    return lhs.path <= rhs.rawValue
}

public func >= <M: _KeyPathQueryableModel, T: Primitive & Comparable>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path >= rhs
}

public func >= <M: _KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive & Comparable {
    return lhs.path >= rhs.rawValue
}

public func < <M: _KeyPathQueryableModel, T: Primitive & Comparable>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path < rhs
}

public func < <M: _KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive & Comparable {
    return lhs.path < rhs.rawValue
}

public func > <M: _KeyPathQueryableModel, T: Primitive & Comparable>(lhs: QuerySubject<M, T>, rhs: T) -> Document {
    return lhs.path > rhs
}

public func > <M: _KeyPathQueryableModel, T: RawRepresentable>(lhs: QuerySubject<M, T>, rhs: T) -> Document where T.RawValue: Primitive & Comparable {
    return lhs.path > rhs.rawValue
}

extension MeowCollection where M: _KeyPathQueryableModel {
    public func find(where matching: (QueryMatcher<M>) -> Document) -> MappedCursor<FindQueryBuilder, M> {
        let query = matching(QueryMatcher<M>())
        return self.find(where: query)
    }
}
#endif
