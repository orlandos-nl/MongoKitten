import BSON
import NIO

/// An aggregate stage that can be used for watching ChangeStream notifications
///
/// When watching changes, this _must_ be the only stage
///
/// ChangeStream is only available to MongoDB 3.6+ users
public struct ChangeStreamStage: Codable {
    private enum CodingKeys: String, CodingKey {
        case options = "$changeStream"
    }
    
    /// The options handed to MongoDB for handling the change stream
    public let options: ChangeStreamOptions
    
    public init(options: ChangeStreamOptions) {
        self.options = options
    }
}

/// Indicates how to process notifications on the MongoDB side before handing them to MongoKitten
public struct ChangeNotificationType: Codable, ExpressibleByStringLiteral {
    private let value: String
    
    /// Nothing special
    public static let `default`: ChangeNotificationType = "default"
    
    /// Indicates that for `update` notifications, the appropriate document needs to be looked up and provided with the notification
    public static let updateLookup: ChangeNotificationType = "updateLookup"
    
    /// Can be used for future notification types
    public init(stringLiteral value: String) {
        self.value = value
    }
    
    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        self.value = try container.decode(String.self)
    }
}

public struct ChangeStreamOptions: Codable {
    public var fullDocument: ChangeNotificationType = .default
    public var resumeAfter: Document?
    public var startAtOperationTime: Timestamp?
    
    public init() {}
}

extension Collection {
    /// Watches for changes within this Collection. Can reflect all mutating operations (Insert, Partial Update, Replace and Delete).
    ///
    /// Options can be provided to alter the type and detail of information being received.
    ///
    /// ChangeStream is only available to MongoDB clusters running MongoDB 3.6+
    public func watch(withOptions options: ChangeStreamOptions = ChangeStreamOptions()) -> EventLoopFuture<ChangeStream<ChangeStreamNotification<Document?>>> {
        let stage = ChangeStreamStage(options: options)
        
        do {
            let document = try BSONEncoder().encode(stage)
            return self.aggregate().append(document).execute().map(ChangeStream.init)
        } catch {
            return self.eventLoop.newFailedFuture(error: error)
        }
    }
}

extension AggregateCursor where Element == Document {
    /// Watches for changes within this Collection. Matches changed documents against the previous stages of this aggregate pipeline.
    /// Can reflect all mutating operations (Insert, Partial Update, Replace and Delete).
    ///
    /// Options can be provided to alter the type and detail of information being received.
    ///
    /// ChangeStream is only available to MongoDB clusters running MongoDB 3.6+
    public func watch(withOptions options: ChangeStreamOptions = ChangeStreamOptions()) -> EventLoopFuture<ChangeStream<ChangeStreamNotification<Document?>>> {
        let stage = ChangeStreamStage(options: options)
        
        do {
            let document = try BSONEncoder().encode(stage)
            self.operation.pipeline.insert(document, at: 0)
            return self.execute().map(ChangeStream.init)
        } catch {
            return self.collection.eventLoop.newFailedFuture(error: error)
        }
    }
}

/// A ChangeStream can be used to watch changes within a collection or database.
///
/// ChangeStream is only available to MongoDB 3.6+ users
public final class ChangeStream<Notification: Decodable> {
    /// The aggregate cursor that is secretly being wrapped
    private let cursor: FinalizedCursor<AggregateCursor<Document>>
    
    fileprivate init(cursor: FinalizedCursor<AggregateCursor<Document>>) {
        self.cursor = cursor
    }
    
    public func close() -> EventLoopFuture<Void> {
        return self.cursor.close()
    }
    
    /// Calls the `handler` for each incoming notification
    ///
    /// On failure, the ChangeStream is aborted
    public func forEach(handler: @escaping (Notification) throws -> Void) {
        cursor.base.decode(Notification.self).forEach(handler: handler)
    }
    
    /// Calls the `handler` for each incoming notification but only continues fetching more notifications when the handler notifies completion through the returned future.
    ///
    /// On failure, the ChangeStream is aborted
    ///
    /// When stopping or cancelling (due to failure), this function's own return value will be completed accordingly.
    public func sequentialForEach(handler: @escaping (Notification) throws -> EventLoopFuture<Void>) -> EventLoopFuture<Void> {
        return cursor.base.decode(Notification.self).sequentialForEach(handler: handler)
    }
}

// TODO: Specialize with Document?
/// A single notification coming from the MongoDB collection/database.
public struct ChangeStreamNotification<FullDocument: Codable>: Codable {
    private enum CodingKeys: String, CodingKey {
        case _id, operationType
        case namespace = "ns"
        case documentKey, updateDescription, fullDocument
    }
    
    /// The namespace where this notification originated from
    public struct Namespace: Codable {
        private enum CodingKeys: String, CodingKey {
            case database = "db"
            case collection = "coll"
        }
        
        /// The database where this occurred in
        public let database: String
        
        /// The collection within the above database
        public let collection: String
    }
    
    /// All operation types that ChangeStream supports watching
    public enum OperationType: String, Codable {
        case insert, update, replace, delete, invalidate, drop
    }
    
    /// An update specification that is only available for update operations
    public struct UpdateDescription: Codable {
        /// The updated fields that are new or have updated values
        public let updatedFields: Document
        
        /// All keys that once were, but are no more
        public let removedFields: [String]
    }
    
    /// A token for resuming the change stream on interruption
    internal let _id: Document
    
    /// All operation types that ChangeStream supports watching
    public let operationType: ChangeStreamNotification.OperationType
    
    /// The namespace where this notification originated from
    public let namespace: ChangeStreamNotification.Namespace
    
    /// Only present for `insert`, `update` `replace` and `delete` operations.
    public let documentKey: Document?
    
    /// Only present in `update` operations
    public var updateDescription: UpdateDescription?
    
    /// Always present in `insert` and `replace`, showing the new document
    ///
    /// Available on `update` if the `updateLookup` is set in the ChangeStreamOptions. Will contain the current Document if it wasn't deleted afterwards.
    public let fullDocument: FullDocument
}
