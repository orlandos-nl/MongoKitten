import MongoKitten
import MongoCore
import Dispatch
import NIO

public final class MeowDatabase {
    public let raw: MongoDatabase
    public var eventLoop: EventLoop { return raw.eventLoop }
    
    public init(_ database: MongoDatabase) {
        self.raw = database
    }
    
    public func collection<M: Model>(for model: M.Type) -> MeowCollection<M> {
        return MeowCollection<M>(database: self, named: M.collectionName)
    }
}

extension MeowDatabase: EventLoopGroup {
    public func makeIterator() -> EventLoopIterator {
        return raw.eventLoop.makeIterator()
    }
    
    public func next() -> EventLoop {
        return raw.eventLoop
    }
    
    public func shutdownGracefully(queue: DispatchQueue, _ callback: @escaping (Error?) -> Void) {
        raw.eventLoop.shutdownGracefully(queue: queue, callback)
    }
}

public struct MeowCollection<M: Model> {
    public let database: MeowDatabase
    public let name: String
    public var raw: MongoCollection { return database.raw[name] }
    public var eventLoop: EventLoop { return database.eventLoop }
    
    public init(database: MeowDatabase, named name: String) {
        self.database = database
        self.name = name
    }
    
    public func insert(_ instance: M) -> EventLoopFuture<InsertReply> {
        do {
            let document = try M.encoder.encode(instance)
            return raw.insert(document)
        } catch {
            return database.eventLoop.makeFailedFuture(error)
        }
    }
    
    public func findOne(where filter: Document) -> EventLoopFuture<M?> {
        return raw.findOne(filter, as: M.self)
    }
    
    public func findOne<Q: MongoKittenQuery>(where filter: Q) -> EventLoopFuture<M?> {
        return raw.findOne(filter, as: M.self)
    }
    
    public func count(where filter: Document) -> EventLoopFuture<Int> {
        return raw.count(filter)
    }
    
    public func count<Q: MongoKittenQuery>(where filter: Q) -> EventLoopFuture<Int> {
        return raw.count(filter.makeDocument())
    }
    
    public func deleteOne(where filter: Document) -> EventLoopFuture<DeleteReply> {
        return raw.deleteOne(where: filter)
    }
    
    public func deleteOne<Q: MongoKittenQuery>(where filter: Q) -> EventLoopFuture<DeleteReply> {
        return raw.deleteOne(where: filter.makeDocument())
    }
    
    public func deleteAll(where filter: Document) -> EventLoopFuture<DeleteReply> {
        return raw.deleteAll(where: filter)
    }
    
    public func deleteAll<Q: MongoKittenQuery>(where filter: Q) -> EventLoopFuture<DeleteReply> {
        return raw.deleteAll(where: filter.makeDocument())
    }
    
    public func upsert(_ instance: M) -> EventLoopFuture<UpdateReply> {
        do {
            let document = try M.encoder.encode(instance)
            return raw.upsert(document, where: "_id" == instance._id)
        } catch {
            return database.eventLoop.makeFailedFuture(error)
        }
    }
    
//    public func saveChanges(_ changes: PartialChange<M>) -> EventLoopFuture<UpdateReply> {
//        return raw.updateOne(where: "_id" == changes.entity, to: [
//            "$set": changes.changedFields,
//            "$unset": changes.removedFields
//        ])
//    }
    
    public func watch() -> EventLoopFuture<ChangeStream<M>> {
        return raw.watch(as: M.self, using: M.decoder)
    }
}

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

extension Model where Self: Equatable {
    /// Compares the given models using the _id
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs._id == rhs._id
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
