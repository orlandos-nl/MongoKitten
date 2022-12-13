import MongoClient
import NIO

/// The options for a change stream
public struct ChangeStreamOptions: Encodable {
    private enum CodingKeys: String, CodingKey {
        case batchSize
        case collation
        case fullDocument
    }
    
    public enum FullDocument: String, Encodable {
        case `default`, updateLookup, whenAvailable, required
    }
    
    
    /// The maximum amount of entities to receive in a `getMore` reply
    public var batchSize: Int32?
    public var collation: Collation?
    
    public var fullDocument: FullDocument?
    
    /// The amount of time that each `getMore` request should wait for more data before replying
    ///
    /// If `nil`, it'll wait until documents are available. In all known current MongoDB versions, this blocks the server's connection handle.
    /// Therefore, only set this to `nil` if you're using a separate connection for this change stream
    ///
    /// Also note that MongoDB will block the connection for `maxAwaitTimeMS` for each `getMore` call
    public var maxAwaitTimeMS: Int64? = 200
    
    public init() {}
}

internal struct ChangeStreamAggregation: AggregateBuilderStage {
    public internal(set) var stage: Document
    public internal(set) var minimalVersionRequired: WireVersion? = .mongo3_6
    
    init(options document: Document) {
        self.stage = ["$changeStream": document]
    }
}

extension MongoCollection {
    /// Creates a change stream for this collection using the given aggregation pipeline
    public func buildChangeStream(
        options: ChangeStreamOptions = .init(),
        @AggregateBuilder build: () -> [AggregateBuilderStage]
    ) async throws -> ChangeStream<Document> {
        try await buildChangeStream(options: options, ofType: Document.self, build: build)
    }
    
    /// Creates a change stream for this collection using the given aggregation pipeline
    /// - Parameters:
    ///  - options: The options for this change stream
    /// - type: The type to decode the change stream notifications into
    /// - decoder: The decoder to use for decoding the change stream notifications
    /// - build: The aggregation pipeline to use for this change stream
    public func buildChangeStream<T: Decodable>(
        options: ChangeStreamOptions = .init(),
        ofType type: T.Type,
        using decoder: BSONDecoder = BSONDecoder(),
        @AggregateBuilder build: () -> [AggregateBuilderStage]
    ) async throws -> ChangeStream<T> {
        let optionsDocument = try BSONEncoder().encode(options)
        let changeStreamStage = ChangeStreamAggregation(options: optionsDocument)
        
        let connection = try await pool.next(for: [.writable, .new, .notPooled])
        
        var pipeline = AggregateBuilderPipeline(stages: build())
        pipeline.connection = connection
        pipeline.stages.insert(changeStreamStage, at: 0)
        pipeline.collection = self
        
        let finalizedCursor = try await pipeline
            .decode(ChangeStreamNotification<T>.self, using: decoder)
            .execute()
        
        finalizedCursor.cursor.maxTimeMS = options.maxAwaitTimeMS.map(Int32.init)
        return ChangeStream(finalizedCursor, options: options)
    }
    
    /// Creates a change stream for this collection using the given aggregation pipeline to watch for changes
    public func watch(
        options: ChangeStreamOptions = .init()
    ) async throws -> ChangeStream<Document> {
        try await watch(
            options: options,
            type: Document.self
        )
    }
    
    /// Creates a change stream for this collection using the given aggregation pipeline to watch for changes
    /// - Parameters:
    /// - options: The options for this change stream
    /// - type: The type to decode the change stream notifications into
    /// - decoder: The decoder to use for decoding the change stream notifications
    public func watch<T: Decodable>(
        options: ChangeStreamOptions = .init(),
        type: T.Type,
        using decoder: BSONDecoder = BSONDecoder()
    ) async throws -> ChangeStream<T> {
        let optionsDocument = try BSONEncoder().encode(options)
        let stage = ChangeStreamAggregation(options: optionsDocument)
        
        let connection = try await pool.next(for: [.writable, .new, .notPooled])
        
        let finalizedCursor = try await _buildAggregate(on: connection) {
            stage
        }
            .decode(ChangeStreamNotification<T>.self)
            .execute()
        
        finalizedCursor.cursor.maxTimeMS = options.maxAwaitTimeMS.map(Int32.init)
        return ChangeStream(finalizedCursor, options: options)
    }
}

/// A change stream is a stream of change notifications for a collection or database
public struct ChangeStream<T: Decodable> {
    public typealias Notification = ChangeStreamNotification<T>
    typealias InputCursor = FinalizedCursor<MappedCursor<AggregateBuilderPipeline, Notification>>
    
    internal let cursor: InputCursor
    internal let options: ChangeStreamOptions
    private var getMoreInterval: TimeAmount?
    
    internal init(_ cursor: InputCursor, options: ChangeStreamOptions) {
        self.cursor = cursor
        self.options = options
    }
    
    /// After each `getMore` request, `getMoreInterval` is used to delay the next `getMore` request
    /// If `getMoreInterval` is configured with `maxAwaitTimeMS`, your connection gets the opportunity to send queries _during_ the `getMoreInterval` window.
    ///
    /// It's therefore adviced to limit use of Change Streams on a shared connection. If you're only using one change stream, you can configure `maxAwaitTimeMS` to a small number, during which no queries can be executed.
    /// Then provide a window of `getMoreInterval` during which queries will be processed and no change events can be processed.
    public mutating func setGetMoreInterval(to interval: TimeAmount? = nil) {
        self.getMoreInterval = interval
    }
    
    /// Iterates over the change stream notifications and calls the given handler for each notification
    /// - Parameter handler: The handler to call for each notification
    /// - Returns: A task that will be completed when the change stream is drained. Can be cancelled to stop the change stream
    /// - Throws: If the handler throws an error, the task will be failed with that error
    @discardableResult
    public func forEach(handler: @escaping @Sendable (Notification) async throws -> Bool) -> Task<Void, Error> {
        Task {
            while !cursor.isDrained {
                for element in try await cursor.nextBatch() {
                    if try await !handler(element) {
                        return
                    }
                }
                
                if let getMoreInterval = self.getMoreInterval {
                    try await Task.sleep(nanoseconds: UInt64(getMoreInterval.nanoseconds))
                } else {
                    try Task.checkCancellation()
                }
            }
        }
    }
}

/// A change stream notification is a notification for a change in a collection or database
public struct ChangeStreamNotification<T: Decodable>: Decodable {
    /// The type of operation that caused this notification
    public enum OperationType: String, Codable {
        case insert, update, replace, delete, invalidate, drop, dropDatabase, rename
    }
    
    public struct ChangeStreamNamespace: Codable {
        private enum CodingKeys: String, CodingKey {
            case database = "db", collection = "coll"
        }
        
        /// The database of the collection or database that was changed
        public let database: String

        /// The collection that was changed
        public let collection: String
    }
    
    /// The update description for this change
    public struct UpdateDescription: Codable {
        /// The fields that were updated
        public let updatedFields: Document

        /// The fields that were removed
        public let removedFields: [String]
    }

    /// The id of the change stream notification
    public let _id: Document

    /// The type of operation that caused this notification
    public let operationType: OperationType

    /// The namespace of the collection or database that was changed
    public let ns: ChangeStreamNamespace

    /// The id of the document that was changed
    public let documentKey: Document?

    /// The update description for this change
    public let updateDescription: UpdateDescription?

    /// The full document that was changed
    public let fullDocument: T?
}
