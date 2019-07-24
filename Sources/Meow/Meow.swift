import MongoKitten
import MongoCore
import NIO

public struct PartialChange<M: Model> {
    public let entity: M.Identifier
    public let changedFields: Document
    public let removedFields: Document
}

public typealias MeowIdentifier = Primitive & Equatable

public protocol Model: Codable {
    associatedtype Identifier: MeowIdentifier
    
    /// The collection name instances of the model live in. A default implementation is provided.
    static var collectionName: String { get }
    
    /// The BSON decoder used for decoding instances of this model. A default implementation is provided.
    static var decoder: BSONDecoder { get }
    
    /// The BSON encoder used for encoding instances of this model. A default implementation is provided.
    static var encoder: BSONEncoder { get }
    
    static var hooks: [MeowHook<Self>] { get }
    
    /// The `_id` of the model. *This property MUST be encoded with `_id` as key*
    var _id: Identifier { get }
}

// MARK: - Default implementations
extension Model {
    public func create(in database: MeowDatabase) -> EventLoopFuture<MeowOperationResult> {
        return database.collection(for: Self.self).upsert(self).map { reply in
            return MeowOperationResult(
                success: reply.updatedCount == 1,
                n: reply.updatedCount,
                writeErrors: reply.writeErrors
            )
        }
    }
    
    public static func watch(in database: MeowDatabase) -> EventLoopFuture<ChangeStream<Self>> {
        return database.collection(for: Self.self).watch()
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
    
    public static var collectionName: String {
        return String(describing: Self.self) // Will be the name of the type
    }
    
    public static var hooks: [MeowHook<Self>] {
        return []
    }
    
    public static var decoder: BSONDecoder {
        return BSONDecoder()
    }
    
    public static var encoder: BSONEncoder {
        return BSONEncoder()
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
