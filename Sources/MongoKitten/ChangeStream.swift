import BSON
import NIO

struct ChangeStreamStage: Codable {
    private enum CodingKeys: String, CodingKey {
        case options = "$changeStream"
    }
    
    let options: ChangeStreamOptions
}

public struct ChangeNotificationType: Codable, ExpressibleByStringLiteral {
    private let value: String
    
    public static let `default`: ChangeNotificationType = "default"
    public static let updateLookup: ChangeNotificationType = "updateLookup"
    
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

extension AggregateCursor where Element == Document {
    public func watch(withOptions options: ChangeStreamOptions = ChangeStreamOptions()) -> EventLoopFuture<ChangeStream> {
        let stage = ChangeStreamStage(options: options)
        
        do {
            let document = try BSONEncoder().encode(stage)
            self.append(document)
            
            return self.execute().map(ChangeStream.init)
        } catch {
            return self.collection.eventLoop.newFailedFuture(error: error)
        }
    }
}

public final class ChangeStream {
    public typealias Element = Document
    
    private let cursor: FinalizedCursor<AggregateCursor<Document>>
    
    init(cursor: FinalizedCursor<AggregateCursor<Document>>) {
        self.cursor = cursor
    }
    
    public func forEach(handler: @escaping (ChangeStreamNotification) throws -> Void) {
        cursor.base.forEach { doc in
            let notification = try BSONDecoder().decode(ChangeStreamNotification.self, from: doc)
            
            try handler(notification)
        }
    }
    
    public func forEachAsync(handler: @escaping (ChangeStreamNotification) throws -> EventLoopFuture<Void>) -> EventLoopFuture<Void> {
        return cursor.base.forEachAsync { doc in
            let notification = try BSONDecoder().decode(ChangeStreamNotification.self, from: doc)
            
            return try handler(notification)
        }
    }
}

public enum OperationType: String, Codable {
    case insert, update, replace, delete, invalidate, drop
}

public struct ChangeStreamNotification: Codable {
    private enum CodingKeys: String, CodingKey {
        case _id, operationType
        case namespace = "ns"
        case documentKey, updateDescription, fullDocument
    }
    
    public struct Namespace: Codable {
        private enum CodingKeys: String, CodingKey {
            case database = "db"
            case collection = "coll"
        }
        
        public let database: String
        public let collection: String
    }
    
    public struct UpdateDescription: Codable {
        public let updatedFields: Document
        public let removedFields: [String]
    }
    
    /// A token for resuming the change stream on interruption
    internal let _id: Document
    
    public let operationType: OperationType
    public let namespace: ChangeStreamNotification.Namespace
    
    /// Only present for `insert`, `update` `replace` and `delete` operations.
    public let documentKey: Document?
    
    /// Only present in `update` operations
    public var updateDescription: UpdateDescription?
    
    /// Always present in `insert` and `replace`, showing the new document
    ///
    /// Available on `update` is the `updateLookup` is set in the ChangeStreamOptions. Will contain the current Document if it wasn't deleted afterwards.
    public let fullDocument: Document?
}
