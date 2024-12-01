import BSON

/// A helper type used in keypath queries that is used as a "virtual model" for constructing type-checked mongodb queries.
///
/// For example, the following query drains all users with the username "Joannis" into an array
///
///     let users = try await meow[User.self].find { user in
///        user.$username == "Joannis"
///     }.drain()
@dynamicMemberLookup
public struct QueryMatcher<M: KeyPathQueryable> {
    internal init() {}

    public subscript<T: Codable>(dynamicMember keyPath: KeyPath<M, QueryableField<T>>) -> QuerySubject<M, T> {
        let path = M.resolveFieldPath(keyPath)
        return QuerySubject(_path: FieldPath(components: path))
    }
}

/// A type, similar to a Swift `KeyPath`, that refers to a value within the entity `M`, inside the database.
///
/// Used to construct type-checked queries
@dynamicMemberLookup
public struct QuerySubject<M: KeyPathQueryable, T: Codable> {
    internal let _path: FieldPath!
    public var path: FieldPath { _path }
    
    public subscript<New>(dynamicMember keyPath: KeyPath<T, QueryableField<New>>) -> QuerySubject<M, New> where T: KeyPathQueryable {
        let path = T.resolveFieldPath(keyPath)
        return QuerySubject<M, New>(_path: FieldPath(components: self.path.components + path))
    }
}

/// A comparator, exclusively to be internally implemented by Meow, to provide syntactically pleasing APIs on QuerySubjects
public protocol QuerySubjectComparator {
    associatedtype Value: Primitive
    
    var path: FieldPath { get }
    var comparator: QuerySubjectComparison { get }
}

/// A size comparator that counts the amount of entites in an array, and can compare the result of that against another value
public struct QuerySubjectSizeComparator: QuerySubjectComparator {
    public typealias Value = Int
    
    public let path: FieldPath
    public var comparator: QuerySubjectComparison {
        .init(key: .size)
    }
}

/// A public type, used internally by Meow to provide syntactically pleasing APIs on QuerySubjects
public struct QuerySubjectComparison {
    internal enum Key: String {
        case size = "$size"
    }
    
    let key: Key
}

extension QuerySubject where T: Sequence {
    /// Produces a query expression that counts the amount of entities in this array
    public var count: QuerySubjectSizeComparator {
        QuerySubjectSizeComparator(path: path)
    }
}

public protocol KeyPathQueryable: Codable {}
public protocol KeyPathQueryableModel: ReadableModel, KeyPathQueryable {}

extension CodingUserInfoKey {
    static let isDiscoveringQuery = CodingUserInfoKey(rawValue: "__meow__discovery_query")!
}

enum MeowModelDecodingError: Error {
    case unknownDecodingKey
}

/// The default supported Model is a ``KeyPathQueryableModel`` that is also a ``MutableModel``. Meaning it's a read-write capable entity that supports type checked APIs'.
///
/// This model type is type-checked, and requires all stored properties to be marked with the ``Field`` property wrapper.
///
/// **Example Model**
///
/// ```swift
/// struct User: Model {
///     @Field var _id: ObjectId
///     @Field var username: String
///     @Field var email: String
///     @Field var createdAt: Date
/// }
/// ```
public typealias Model = KeyPathQueryableModel & MutableModel

extension KeyPathQueryable {
    /// Resolves a ``QueryableField`` into `[String]` path.
    ///
    /// - Note: Crashes if the model does not implement Meow's @``Field`` property wrapper on all properties
    internal static func _resolveFieldPath<T>(_ field: QueryableField<T>) -> [String] {
        // If the app crashes here, it's most likely that you didn't properly implement the `@Field` property wrapper in your model
        return field.parents + [field.key!]
    }
    
    /// Resolves a ``QueryableField`` into `[String]` path.
    ///
    /// - Note: Crashes if the model does not implement the @``Field`` property wrapper on all properties
    public static func resolveFieldPath<T: Codable>(_ field: KeyPath<Self, QueryableField<T>>) -> [String] {
        resolveFieldPath(field.appending(path: \.wrapper))
    }
    
    /// Resolves a Field into `[String]` path.
    ///
    /// - Note: Crashes if the model does not implement the @``Field`` property wrapper on all properties
    public static func resolveFieldPath<T: Codable>(_ field: KeyPath<Self, Field<T>>) -> [String] {
        resolveFieldPath(field.appending(path: \.projectedValue.wrapper))
    }

    internal static func resolveFieldPath<T>(_ field: KeyPath<Self, _QueryableFieldWrapper<T>>) -> [String] {
        // If you've arrived here, please add `@Field` to all your model's propertiess
        do {
            let model = try Self(from: TestDecoder())
            let field = model[keyPath: field]
            switch field.wrapped {
            case .field(let field):
                return _resolveFieldPath(field.projectedValue)
            case .queryableField(let field):
                return _resolveFieldPath(field)
            }
        } catch {
            fatalError("If you've arrived here, please add `@Field` to all your \(Self.self) model's properties")
        }
    }
}

extension KeyPathQueryableModel where Self: MutableModel {
    /// Constructs a partial (atomic) update to this model by allowing you to update individual values in this model
    /// Each value that's been updated will be `$set` in the database
    ///
    /// Produces a `PartialUpdate` that can be executed as a query
    ///
    /// - Note:If the model is a class, the model will be updated before `PartialUpdate.apply` is called
    public func makePartialUpdate(_ mutate: (inout ModelUpdater<Self>) async throws -> Void) async rethrows -> PartialUpdate<Self> {
        var updater = ModelUpdater(model: self)
        try await mutate(&updater)
        return updater.update
    }
}

/// A helper/proxy type that changes values on the subjected model, and keeps track of all changed fields
@dynamicMemberLookup
public struct ModelUpdater<M: KeyPathQueryableModel & MutableModel> {
    var update: PartialUpdate<M>
    
    internal init(model: M) {
        self.update = PartialUpdate(
            model: model
        )
    }
    
    public subscript<P: PrimitiveEncodable & Codable>(dynamicMember keyPath: WritableKeyPath<M, QueryableField<P>>) -> P {
        get {
            update.model[keyPath: keyPath].value!
        }
        set {
            update.model[keyPath: keyPath].value = newValue
            update.setField(
                at: M.resolveFieldPath(keyPath),
                to: try newValue.encodePrimitive()
            )
        }
    }
}

/// A partial update, as result of `Model.makePartialUpdate` that can be executed on a collection to atomically `$set` these changes
///
///     let updatedUser = try await user.makePartialUpdate { user in
///         user.$password = newPasswordHash
///     }.apply(on: meow[User.self])
public struct PartialUpdate<M: KeyPathQueryableModel & MutableModel> {
    var model: M
    var valuesForSetting: [[String]: () throws -> Primitive] = [:]
    
    mutating func setField(at path: [String], to newValue: @autoclosure @escaping () throws -> Primitive) {
        valuesForSetting[path] = newValue
    }
    
    var changes: Document {
        get throws {
            try valuesForSetting.reduce(into: Document()) { doc, change in doc[change.key] = try change.value() }
        }
    }
    
    /// Applies the changes and returns an updated model
    public func apply(on collection: MeowCollection<M>) async throws -> M {
        guard try await collection.raw.updateOne(
            where: "_id" == model._id.encodePrimitive(),
            to: ["$set": changes]
        ).updatedCount == 1 else {
            throw MeowModelError<M>.cannotUpdate(model._id)
        }
        
        return model
    }
    
    /// Applies the changes and returns an updated model
    public func apply(in database: MeowDatabase) async throws -> M {
        try await apply(on: database.collection(for: M.self))
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

extension KeyPath: FieldPathRepresentable where Root: KeyPathQueryable, Value: _QueryableFieldRepresentable {
    public func makeFieldPath() -> FieldPath {
        FieldPath(components: Root.resolveFieldPath(self.appending(path: \.wrapper)))
    }
}

extension String: FieldPathRepresentable {
    public func makeFieldPath() -> FieldPath {
        FieldPath(stringLiteral: self)
    }
}

extension FieldPath: FieldPathRepresentable {
    public func makeFieldPath() -> FieldPath {
        self
    }
}

public struct _QueryableFieldWrapper<Value: Codable> {
    internal enum _Wrapper {
        case queryableField(QueryableField<Value>)
        case field(Field<Value>)
    }

    let wrapped: _Wrapper
}

public protocol _QueryableFieldRepresentable {
    associatedtype Value: Codable
    
    var wrapper: _QueryableFieldWrapper<Value> { get }
}

public protocol FieldPathRepresentable {
    func makeFieldPath() -> FieldPath
}

/// A wrapper around a value, that can be aware of its full keypath within the Model
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

extension QueryableField: _QueryableFieldRepresentable where Value: Codable {
    public var wrapper: _QueryableFieldWrapper<Value> {
        .init(wrapped: .queryableField(self))
    }
}

/// The `@Field` property wrapper is used on all stored properties of a ``Model`` to allow key path based queries.
@propertyWrapper
public struct Field<C: Codable>: Codable, _QueryableFieldRepresentable, Sendable {
    public typealias Value = C
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

    public var wrapper: _QueryableFieldWrapper<Value> {
        .init(wrapped: .field(self))
    }
    
    public init(from decoder: Decoder) throws {
        guard let key = decoder.codingPath.last?.stringValue else {
            throw MeowModelDecodingError.unknownDecodingKey
        }
        
        self.key = key
        
        if decoder is TestDecoder {
            self._wrappedValue = try? C(from: decoder)
        } else {
            let container = try decoder.singleValueContainer()
            self._wrappedValue = try container.decode(C.self)
        }
    }
    
    public init(wrappedValue: C) {
        self.key = nil
        self._wrappedValue = wrappedValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(_wrappedValue!)
    }
}

extension Field: Equatable where C: Equatable {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}

extension Field: Hashable where C: Hashable {
    public func hash(into hasher: inout Hasher) {
        wrappedValue.hash(into: &hasher)
    }
}

/// A property wrapper helper type that holds a reference to another entity
///
/// Functions as an equivalent to @``Field``
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
