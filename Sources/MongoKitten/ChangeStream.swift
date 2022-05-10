import MongoClient
import NIO

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
    public func buildChangeStream(
        options: ChangeStreamOptions = .init(),
        @AggregateBuilder build: () -> [AggregateBuilderStage]
    ) async throws -> ChangeStream<Document> {
        try await buildChangeStream(options: options, ofType: Document.self, build: build)
    }
    
    public func buildChangeStream<T: Decodable>(
        options: ChangeStreamOptions = .init(),
        ofType type: T.Type,
        using decoder: BSONDecoder = BSONDecoder(),
        @AggregateBuilder build: () -> [AggregateBuilderStage]
    ) async throws -> ChangeStream<T> {
        let optionsDocument = try BSONEncoder().encode(options)
        let changeStreamStage = ChangeStreamAggregation(options: optionsDocument)
        
        let connection = try await pool.next(for: [.writable, .new])
        
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
    
    public func watch(
        options: ChangeStreamOptions = .init()
    ) async throws -> ChangeStream<Document> {
        try await watch(
            options: options,
            type: Document.self
        )
    }
    
    public func watch<T: Decodable>(
        options: ChangeStreamOptions = .init(),
        type: T.Type,
        using decoder: BSONDecoder = BSONDecoder()
    ) async throws -> ChangeStream<T> {
        let optionsDocument = try BSONEncoder().encode(options)
        let stage = ChangeStreamAggregation(options: optionsDocument)
        
        let connection = try await pool.next(for: [.writable, .new])
        
        let finalizedCursor = try await _buildAggregate(on: connection) {
            stage
        }
            .decode(ChangeStreamNotification<T>.self)
            .execute()
        
        finalizedCursor.cursor.maxTimeMS = options.maxAwaitTimeMS.map(Int32.init)
        return ChangeStream(finalizedCursor, options: options)
    }
}

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

public struct ChangeStreamNotification<T: Decodable>: Decodable {
    public enum OperationType: String, Codable {
        case insert, update, replace, delete, invalidate, drop, dropDatabase, rename
    }
    
    public struct ChangeStreamNamespace: Codable {
        private enum CodingKeys: String, CodingKey {
            case database = "db", collection = "coll"
        }
        
        public let database: String
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
