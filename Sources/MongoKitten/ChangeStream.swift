import MongoClient
import NIO

public struct ChangeStreamOptions: Codable {
    public var batchSize: Int32?
    public var collation: Collation?
    public var maxAwaitTimeMS: Int64?
    
    public init() {}
}

extension MongoCollection {
    /// Watches for all changes in this collection
    public func watch(
        options: ChangeStreamOptions = .init()
    ) -> EventLoopFuture<ChangeStream<Document>> {
        return watch(options: options, as: Document.self)
    }
    
    /// Watches for all changes in this collection, and decodes entities to `T`
    public func watch<T: Decodable>(
        options: ChangeStreamOptions = .init(),
        as type: T.Type,
        using decoder: BSONDecoder = BSONDecoder()
    ) -> EventLoopFuture<ChangeStream<T>> {
        do {
            let options = try BSONEncoder().encode(options)
            let stage = AggregateBuilderStage(document: [
                "$changeStream": options
            ])
            
            let pipeline = self.aggregate([stage]).decode(
                ChangeStreamNotification<T>.self,
                using: decoder
            )
            
            return pipeline.execute().map(ChangeStream.init)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
}

public struct ChangeStream<T: Decodable> {
    public typealias Notification = ChangeStreamNotification<T>
    typealias InputCursor = FinalizedCursor<MappedCursor<AggregateBuilderPipeline, Notification>>
    
    internal let cursor: InputCursor
    
    internal init(_ cursor: InputCursor) {
        self.cursor = cursor
    }
    
    public func forEach(handler: @escaping (Notification) -> Bool) {
        func nextBatch() -> EventLoopFuture<Void> {
            return cursor.nextBatch(failable: true).flatMap { batch in
                for element in batch {
                    if !handler(element) {
                        return self.cursor.base.eventLoop.makeSucceededFuture(())
                    }
                }

                if self.cursor.isDrained {
                    return self.cursor.base.eventLoop.makeSucceededFuture(())
                }

                return nextBatch()
            }
        }
        
        _ = nextBatch()
    }
}

public struct ChangeStreamNotification<T: Decodable>: Decodable {
    public enum OperationType: String, Codable {
        case insert, update, replace, delete, invalidate, drop, dropDatabase, rename
    }
    
    public struct ChangeStreamNamespace: Codable {
        private enum CodingKeys: String, CodingKey {
            case database = "db", collection = "coll"
        }
        
        /// The name of the database where the notification occurrd
        public let database: String
        
        /// The name of the collection where the notification occurrd
        public let collection: String
    }
    
    public struct UpdateDescription: Codable {
        public let updatedFields: Document
        public let removedFields: [String]
    }
    
    public let _id: Document
    public let operationType: OperationType
    
    public let ns: ChangeStreamNamespace
    public let documentKey: Document?
    public let updateDescription: UpdateDescription?
    public let fullDocument: T?
}
