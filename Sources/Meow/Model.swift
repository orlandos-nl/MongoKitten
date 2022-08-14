import MongoKitten
import MongoCore
import NIO

/// All Meow models must have an identifier that is `Codable` and `Hashable`, as well as representable by a Primitive.
///
/// When implementing `PrimitiveEncodable` using `BSONEncoder`, this allows you to use any `struct` as an `_id` so long as it's not an "unkeyedContainer". Array-like (sequence) types are rejected on insertion by MongoDB.
public typealias MeowIdentifier = Codable & Hashable & PrimitiveEncodable

/// The base specification of any Meow model, containing a collectionName and a _id
///
/// All Meow models must have an identifier that is `Codable` and `Hashable`, as well as representable by a Primitive.
///
/// When implementing `PrimitiveEncodable` using `BSONEncoder`, this allows you to use any `struct` as an `_id` so long as it's not an "unkeyedContainer". Array-like (sequence) types are rejected on insertion by MongoDB.
public protocol BaseModel {
    associatedtype Identifier: MeowIdentifier
    
    /// The collection name instances of the model live in. A default implementation is provided.
    ///
    /// The default collection name is the model's type name
    static var collectionName: String { get }
    
    /// The `_id` of the model. *This property MUST be encoded with `_id` as key*
    var _id: Identifier { get }
}

/// The base specification of any _readable_ Meow model, containing a collectionName and a _id.
/// ReadableModel must be implemented using `Decodable`. ReadableModel is currently used for any entity that is queryable.
/// MutableModels can be saved, whereas Readableodels cannot
///
/// Two models may share the same collection, allowing for constructions where both `AdminUser`
///
/// Example:
///
///     struct AnyUser: MutableModel {
///         @Field var _id: ObjectId
///         @Field var username: String
///         @Field var role: Role
///
///         // Populted only for admin users
///         @Field var adminPowers: [AdminPrivilege]?
///     }
///     struct AdminUser: ReadableModel {
///         let _id: ObjectId
///         let username: String
///         // Role is always admin for this model, so it's not decoded
///         // Always populated
///         let adminPowers: [AdminPrivilege]
///     }
///     struct User: ReadableModel {
///         let _id: ObjectId
///         let username: String
///         @Field var role: Role
///         // `adminPowers` are not relevant
///     }
///
/// All Meow models must have an identifier that is `Codable` and `Hashable`, as well as representable by a Primitive.
///
/// When implementing `PrimitiveEncodable` using `BSONEncoder`, this allows you to use any `struct` as an `_id` so long as it's not an "unkeyedContainer". Array-like (sequence) types are rejected on insertion by MongoDB.
public protocol ReadableModel: BaseModel, Decodable {
    static func decode(from document: Document) throws -> Self
    static var decoder: BSONDecoder { get }
}

/// The base specification of any _readable_ Meow model, containing a collectionName and a _id.
/// MutableModel must be implemented using `Codable`, and always implements ReadableModel.
/// MutableModels can be saved, whereas Readableodels cannot
///
/// Two models may share the same collection, allowing for constructions where both `AdminUser`
///
/// Example:
///
///     struct AnyUser: MutableModel {
///         @Field var _id: ObjectId
///         @Field var username: String
///         @Field var role: Role
///
///         // Populted only for admin users
///         @Field var adminPowers: [AdminPrivilege]?
///     }
///     struct AdminUser: ReadableModel {
///         let _id: ObjectId
///         let username: String
///         // Role is always admin for this model, so it's not decoded
///         // Always populated
///         let adminPowers: [AdminPrivilege]
///     }
///     struct User: ReadableModel {
///         let _id: ObjectId
///         let username: String
///         @Field var role: Role
///         // `adminPowers` are not relevant
///     }
///
/// All Meow models must have an identifier that is `Codable` and `Hashable`, as well as representable by a Primitive.
///
/// When implementing `PrimitiveEncodable` using `BSONEncoder`, this allows you to use any `struct` as an `_id` so long as it's not an "unkeyedContainer". Array-like (sequence) types are rejected on insertion by MongoDB.
public protocol MutableModel: ReadableModel, Encodable {
    func encode(to document: Document.Type) throws -> Document
    static var encoder: BSONEncoder { get }
}

extension BaseModel {
    /// The default collection name is the model's type name
    public static var collectionName: String {
        return String(describing: Self.self) // Will be the name of the type
    }
}

extension ReadableModel {
    @inlinable public static var decoder: BSONDecoder { .init() }
    
    @inlinable
    public static func decode(from document: Document) throws -> Self {
        try Self.decoder.decode(Self.self, from: document)
    }
    
    
    /// Creates a `ChangeStream`,watching for any and all changes to this Model's collection within `database`
    ///
    /// - Note: Only works in replica set environments
    public static func watch(options: ChangeStreamOptions = .init(), in database: MeowDatabase) async throws -> ChangeStream<Self> {
        return try await database.collection(for: Self.self).watch(options: options)
    }
    
    /// Counts all instances of `Self` matching `filter` within the provided `database`
    public static func count(
        where filter: Document = Document(),
        in database: MeowDatabase
    ) async throws -> Int {
        return try await database.collection(for: Self.self).count(where: filter)
    }
    
    /// Counts all instances of `Self` matching `filter` within the provided `database`
    public static func count<Q: MongoKittenQuery>(
        where filter: Q,
        in database: MeowDatabase
    ) async throws -> Int {
        return try await database.collection(for: Self.self).count(where: filter)
    }
}

// MARK: - Default implementations
extension MutableModel {
    /// Saves this model using an `upsert` operation, updating if it exists, creating if it's new
    @discardableResult
    public func save(in database: MeowDatabase) async throws -> MeowOperationResult {
        let reply = try await database.collection(for: Self.self).upsert(self)
        return MeowOperationResult(
            success: reply.updatedCount == 1 || reply.upserted != nil,
            n: reply.updatedCount,
            writeErrors: reply.writeErrors
        )
    }
    
    /// Creates this model using an `insert` operation. Fails if the entity already exists
    @discardableResult
    public func create(in database: MeowDatabase) async throws -> MeowOperationResult {
        let reply = try await database.collection(for: Self.self).insert(self)
        return MeowOperationResult(
            success: reply.insertCount == 1,
            n: reply.insertCount,
            writeErrors: reply.writeErrors
        )
    }
    
    /// Replaces the old model matching this `_id` with the current model. Returns the old model if the entity existed
    public func replaceModel(in database: MeowDatabase) async throws -> Self? {
        try await database
            .collection(for: Self.self)
            .raw
            .findOneAndUpsert(
                where: "_id" == _id.encodePrimitive(),
                replacement: try BSONEncoder().encode(self),
                returnValue: .original
            )
            .decode(Self.self)
    }
    
    @inlinable public static var encoder: BSONEncoder { .init() }
    
    @inlinable
    public func encode(to document: Document.Type) throws -> Document {
        try Self.encoder.encode(self)
    }
}

public enum MeowHook<M: BaseModel> {}

public struct MeowOperationResult {
    public struct NotSuccessful: Error {}
    
    public let success: Bool
    public let n: Int
    public let writeErrors: [MongoWriteError]?
    
    public func assertCompleted() throws {
        guard success else {
            throw MeowOperationResult.NotSuccessful()
        }
    }
}
