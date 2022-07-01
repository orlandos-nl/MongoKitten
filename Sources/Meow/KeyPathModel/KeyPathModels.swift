import BSON

@dynamicMemberLookup
public struct QueryMatcher<M: KeyPathQueryable> {
    internal init() {}

    public subscript<T>(dynamicMember keyPath: KeyPath<M, QueryableField<T>>) -> QuerySubject<M, T> {
        let path = M.resolveFieldPath(keyPath)
        return QuerySubject(path: FieldPath(components: path))
    }
}

@dynamicMemberLookup
public struct QuerySubject<M: KeyPathQueryable, T> {
    internal let path: FieldPath!
    
    public subscript<New>(dynamicMember keyPath: KeyPath<T, QueryableField<New>>) -> QuerySubject<M, New> where T: KeyPathQueryable {
        let path = T.resolveFieldPath(keyPath)
        return QuerySubject<M, New>(path: FieldPath(components: self.path.components + path))
    }
}

public protocol QuerySubjectComparator {
    associatedtype Value: Primitive
    
    var path: FieldPath { get }
    var comparator: QuerySubjectComparison { get }
}

public struct QuerySubjectSizeComparator: QuerySubjectComparator {
    public typealias Value = Int
    
    public let path: FieldPath
    public var comparator: QuerySubjectComparison {
        .init(key: .size)
    }
}

public struct QuerySubjectComparison {
    internal enum Key: String {
        case size = "$size"
    }
    
    let key: Key
}

extension QuerySubject where T: Sequence {
    public var count: QuerySubjectSizeComparator {
        QuerySubjectSizeComparator(path: path)
    }
}

public protocol KeyPathQueryable: Codable {
    //    static func makeFieldPath<T>(forKeyPath keyPath: KeyPath<Self, T>) -> FieldPath
    //    static func makePathComponents<T>(forKeyPath keyPath: KeyPath<Self, T>) -> [String]
}

extension KeyPathQueryable {
    //    public static func makeFieldPath<T>(forKeyPath keyPath: KeyPath<Self, T>) -> FieldPath {
    //        FieldPath(components: makePathComponents(forKeyPath: keyPath))
    //    }
}

public protocol KeyPathQueryableModel: ReadableModel, KeyPathQueryable {}

extension CodingUserInfoKey {
    static let isDiscoveringQuery = CodingUserInfoKey(rawValue: "__meow__discovery_query")!
}

enum MeowModelDecodingError: Error {
    case unknownDecodingKey
}

public typealias Model = KeyPathQueryableModel & MutableModel

extension KeyPathQueryable {
    internal static func resolveFieldPath<T>(_ field: QueryableField<T>) -> [String] {
        return field.parents + [field.key!]
    }
    
    public static func resolveFieldPath<T>(_ field: KeyPath<Self, QueryableField<T>>) -> [String] {
        let model = try! Self(from: TestDecoder())
        let field = model[keyPath: field]
        
        return resolveFieldPath(field)
    }
    
    public static func resolveFieldPath<T>(_ field: KeyPath<Self, Field<T>>) -> [String] {
        resolveFieldPath(field.appending(path: \.projectedValue))
    }
}

extension KeyPathQueryableModel where Self: MutableModel {
    public func makePartialUpdate(_ mutate: (inout ModelUpdater<Self>) async throws -> Void) async rethrows -> PartialUpdate<Self> {
        var updater = ModelUpdater(model: self)
        try await mutate(&updater)
        return updater.update
    }
}

@dynamicMemberLookup
public struct ModelUpdater<M: KeyPathQueryableModel & MutableModel> {
    var update: PartialUpdate<M>
    
    internal init(model: M) {
        self.update = PartialUpdate(
            model: model
        )
    }
    
    public subscript<P: Primitive>(dynamicMember keyPath: WritableKeyPath<M, QueryableField<P>>) -> P {
        get {
            update.model[keyPath: keyPath].value!
        }
        set {
            update.model[keyPath: keyPath].value = newValue
            
            let path = M.resolveFieldPath(keyPath)
            update.changes[path] = newValue
        }
    }
}

public struct PartialUpdate<M: KeyPathQueryableModel & MutableModel> {
    var model: M
    var changes = Document()
    
    public func apply(on collection: MeowCollection<M>) async throws -> M {
        guard try await collection.raw.updateOne(
            where: "_id" == model._id.encodePrimitive(),
            to: ["$set": changes]
        ).updatedCount == 1 else {
            throw MeowModelError<M>.cannotUpdate(model._id)
        }
        
        return model
    }
}

fileprivate extension Document {
    subscript(path: [String]) -> Primitive? {
        get {
            if path.isEmpty {
                return self
            }
            
            var path = path
            let key = path.removeFirst()
            
            if let document = self[key] as? Document {
                return document[path]
            } else {
                return Document()
            }
        }
        set {
            if path.isEmpty {
                return
            }
            
            var path = path
            let key = path.removeFirst()
            
            if path.isEmpty {
                self[key] = newValue
            } else {
                var document = (self[key] as? Document) ?? Document()
                document[path] = newValue
                self[key] = document
            }
        }
    }
}

@dynamicMemberLookup
public struct QueryableField<Value> {
    internal let parents: [String]
    internal let key: String?
    internal var value: Value?
    
    internal var isInvalid: Bool { key == nil }
    
    public subscript<T>(dynamicMember keyPath: KeyPath<Value, QueryableField<T>>) -> QueryableField<T> {
        if let key = key, let value = value {
            let subField = value[keyPath: keyPath]
            
            return QueryableField<T>(
                parents: parents + [key],
                key: subField.key,
                value: subField.value
            )
        } else {
            return QueryableField<T>(
                parents: [],
                key: nil,
                value: nil
            )
        }
    }
}

@propertyWrapper
public struct Field<C: Codable>: Codable {
    public let key: String?
    private var _wrappedValue: C?
    
    public var wrappedValue: C {
        get { _wrappedValue! }
        set { _wrappedValue = newValue }
    }
    
    public var projectedValue: QueryableField<C> {
        get { QueryableField(parents: [], key: key, value: _wrappedValue) }
        set { _wrappedValue = newValue.value }
    }
    
    public init(from decoder: Decoder) throws {
        guard let key = decoder.codingPath.last?.stringValue else {
            throw MeowModelDecodingError.unknownDecodingKey
        }
        
        self.key = key
        
        if decoder is TestDecoder {
            self._wrappedValue = try? C(from: decoder)
        } else {
            self._wrappedValue = try C(from: decoder)
        }
    }
    
    public init(wrappedValue: C) {
        self.key = nil
        self._wrappedValue = wrappedValue
    }
    
    public func encode(to encoder: Encoder) throws {
        try _wrappedValue!.encode(to: encoder)
    }
}

extension Field: Equatable where C: Equatable {}
extension Field: Hashable where C: Hashable {}

@propertyWrapper
public struct ID<Wrapped: MeowIdentifier>: Codable {
    public var key: String { "_id" }
    private var _wrappedValue: Wrapped?
    
    public var wrappedValue: Wrapped {
        get { _wrappedValue! }
        set { _wrappedValue = newValue }
    }
    
    public var projectedValue: QueryableField<Wrapped> {
        QueryableField(parents: [], key: key, value: _wrappedValue)
    }
    
    public init(from decoder: Decoder) throws {
        if decoder is TestDecoder {
            self._wrappedValue = try? Wrapped(from: decoder)
        } else {
            self._wrappedValue = try Wrapped(from: decoder)
        }
    }
    
    public init(wrappedValue: Wrapped) {
        self._wrappedValue = wrappedValue
    }
    
    public func encode(to encoder: Encoder) throws {
        try _wrappedValue!.encode(to: encoder)
    }
}

@propertyWrapper
public struct ReferenceField<M: BaseModel>: Codable {
    public let key: String?
    private var _wrappedValue: M.Identifier?
    
    public var wrappedValue: M.Identifier {
        get { _wrappedValue! }
        set { _wrappedValue = newValue }
    }
    
    public var projectedValue: QueryableField<M.Identifier> {
        QueryableField(parents: [], key: key, value: _wrappedValue)
    }
    
    public init(from decoder: Decoder) throws {
        guard let key = decoder.codingPath.last?.stringValue else {
            throw MeowModelDecodingError.unknownDecodingKey
        }
        
        self.key = key
        
        if decoder is TestDecoder {
            self._wrappedValue = try? M.Identifier(from: decoder)
        } else {
            self._wrappedValue = try M.Identifier(from: decoder)
        }
    }
    
    public init(wrappedValue: M.Identifier) {
        self.key = nil
        self._wrappedValue = wrappedValue
    }
    
    public func encode(to encoder: Encoder) throws {
        try _wrappedValue!.encode(to: encoder)
    }
}
