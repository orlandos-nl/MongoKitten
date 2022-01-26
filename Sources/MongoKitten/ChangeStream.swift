import MongoClient
import NIO

public struct ChangeStreamOptions: Encodable {
    private enum CodingKeys: String, CodingKey {
        case batchSize
        case collation
    }
    
    public var batchSize: Int32?
    public var collation: Collation?
    public var maxAwaitTimeMS: Int64?
    
    public init() {}
}

extension MongoCollection {
    public func buildChangeStream(
        options: ChangeStreamOptions = .init(),
        using decoder: BSONDecoder = BSONDecoder(),
        @AggregateBuilder build: () -> AggregateBuilderStage
    ) async throws -> ChangeStream<Document> {
        try await buildChangeStream(options: options, as: Document.self, using: decoder, build: build)
    }
    
    public func buildChangeStream<T: Decodable>(
        options: ChangeStreamOptions = .init(),
        as type: T.Type,
        using decoder: BSONDecoder = BSONDecoder(),
        @AggregateBuilder build: () -> AggregateBuilderStage
    ) async throws -> ChangeStream<T> {
        let optionsDocument = try BSONEncoder().encode(options)
        let changeStreamStage = AggregateBuilderStage(document: [
            "$changeStream": optionsDocument
        ])
        
        var pipeline = AggregateBuilderPipeline(stages: [build()])
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
        return try await watch(options: options, as: Document.self)
    }
    
    public func watch<T: Decodable>(
        options: ChangeStreamOptions = .init(),
        as type: T.Type,
        using decoder: BSONDecoder = BSONDecoder()
    ) async throws -> ChangeStream<T> {
        let optionsDocument = try BSONEncoder().encode(options)
        let stage = AggregateBuilderStage(document: [
            "$changeStream": optionsDocument
        ])
        
        let pipeline = self.aggregate([stage]).decode(
            ChangeStreamNotification<T>.self,
            using: decoder
        )
        
        let finalizedCursor = try await pipeline.execute()
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
    
    public mutating func setGetMoreInterval(to interval: TimeAmount? = nil) {
        self.getMoreInterval = interval
    }
    
    @discardableResult
    public func forEach(handler: @escaping (Notification) async throws -> Bool) -> Task<Void, Error> {
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
