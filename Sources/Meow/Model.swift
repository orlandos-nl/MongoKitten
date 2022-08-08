import MongoKitten
import MongoCore
import NIO

//public struct PartialChange<M: Model> {
//    public let entity: M.Identifier
//    public let changedFields: Document
//    public let removedFields: Document
//}

public typealias MeowIdentifier = Primitive & Equatable

public protocol BaseModel {
    associatedtype Identifier: MeowIdentifier
    
    /// The collection name instances of the model live in. A default implementation is provided.
    static var collectionName: String { get }
    
    /// The `_id` of the model. *This property MUST be encoded with `_id` as key*
    var _id: Identifier { get }
}

public protocol ReadableModel: BaseModel, Decodable {
    static func decode(from document: Document) throws -> Self
    static var decoder: BSONDecoder { get }
}

public protocol MutableModel: ReadableModel, Encodable {
    func encode(to document: Document.Type) throws -> Document
    static var encoder: BSONEncoder { get }
}

public typealias Model = MutableModel

extension BaseModel {
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
    
    public static func watch(options: ChangeStreamOptions = .init(), in database: MeowDatabase) -> EventLoopFuture<ChangeStream<Self>> {
        return database.collection(for: Self.self).watch(options: options)
    }
    
    public static func count(
        where filter: Document = Document(),
        in database: MeowDatabase
    ) -> EventLoopFuture<Int> {
        return database.collection(for: Self.self).count(where: filter)
    }
    
    public static func count<Q: MongoKittenQuery>(
        where filter: Q,
        in database: MeowDatabase
    ) -> EventLoopFuture<Int> {
        return database.collection(for: Self.self).count(where: filter)
    }
}

// MARK: - Default implementations
extension MutableModel {
    @available(*, renamed: "save")
    public func create(in database: MeowDatabase) -> EventLoopFuture<MeowOperationResult> {
        save(in: database)
    }
    
    public func save(in database: MeowDatabase) -> EventLoopFuture<MeowOperationResult> {
        return database.collection(for: Self.self).upsert(self).map { reply in
            return MeowOperationResult(
                success: reply.updatedCount == 1 || reply.upserted != nil,
                n: reply.updatedCount,
                writeErrors: reply.writeErrors
            )
        }
    }
    
    @inlinable public static var encoder: BSONEncoder { .init() }
    
    @inlinable
    public func encode(to document: Document.Type) throws -> Document {
        try Self.encoder.encode(self)
    }
}

public enum MeowHook<M: Model> {}

public struct MeowOperationResult {
    public struct NotSuccessful: Error {}
    
    public let success: Bool
    public let n: Int
    public let writeErrors: [MongoWriteError]?
}

extension EventLoopFuture where Value == MeowOperationResult {
    public func assertCompleted() -> EventLoopFuture<Void> {
        return flatMapThrowing { result in
            guard result.success else {
                throw MeowOperationResult.NotSuccessful()
            }
        }
    }
}
