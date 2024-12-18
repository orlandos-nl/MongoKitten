import MongoClient
import NIO

/// The options for a change stream
///
/// Change stream options control how changes are tracked and delivered from MongoDB.
/// These options affect performance, resource usage, and the content of change notifications.
///
/// ## Basic Usage
/// ```swift
/// var options = ChangeStreamOptions()
/// options.fullDocument = .updateLookup // Include full documents on updates
/// options.batchSize = 100 // Process changes in batches
/// options.maxAwaitTimeMS = 1000 // Wait up to 1 second for changes
/// ```
///
/// ## Full Document Options
/// - `default`: Only include changed fields
/// - `updateLookup`: Include the full document after updates
/// - `whenAvailable`: Include full document if available
/// - `required`: Error if full document is not available
///
/// ## Performance Considerations
/// - Use `batchSize` to control memory usage and network traffic
/// - Set `maxAwaitTimeMS` to balance responsiveness and server load
///
/// ## Example with All Options
/// ```swift
/// var options = ChangeStreamOptions()
/// options.fullDocument = .updateLookup
/// options.batchSize = 100
/// options.maxAwaitTimeMS = 1000
/// options.collation = Collation(locale: "en")
/// ```
///
/// ## Implementation Details
/// - Change streams require a replica set or sharded cluster
/// - The server may close inactive streams after 30 minutes
/// - Streams automatically resume after network interruptions
public struct ChangeStreamOptions: Encodable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case batchSize
        case collation
        case fullDocument
    }
    
    public enum FullDocument: String, Encodable, Sendable {
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
    /// Creates a change stream for this collection using the given aggregation pipeline.
    ///
    /// Change streams allow applications to track real-time changes to MongoDB data.
    /// This method creates a change stream with a custom aggregation pipeline for
    /// filtering or transforming change events.
    ///
    /// ## Basic Usage
    /// ```swift
    /// // Watch for specific changes
    /// let stream = try await users.buildChangeStream {
    ///     // Only watch for inserts and updates
    ///     Match(where: [
    ///         "operationType": ["$in": ["insert", "update"]]
    ///     ])
    ///     
    ///     // Only include specific fields
    ///     Project([
    ///         "fullDocument.name": 1,
    ///         "fullDocument.email": 1
    ///     ])
    /// }
    ///
    /// for try await change in stream {
    ///     print("Change detected: \(change)")
    /// }
    /// ```
    ///
    /// ## Type-Safe Changes
    /// ```swift
    /// struct User: Codable {
    ///     let id: ObjectId
    ///     let name: String
    ///     let email: String
    /// }
    ///
    /// let stream = try await users.buildChangeStream(
    ///     ofType: User.self
    /// ) {
    ///     // Filter for premium users
    ///     Match(where: "fullDocument.isPremium" == true)
    /// }
    /// ```
    ///
    /// ## Performance Considerations
    /// - Use pipeline stages to filter changes early
    /// - Configure maxAwaitTimeMS to balance responsiveness and server load
    ///
    /// ## Implementation Details
    /// - Requires MongoDB 3.6 or later
    /// - Only works with replica sets or sharded clusters
    /// - Automatically resumes after network interruptions
    /// - Uses a separate connection by default
    public func buildChangeStream(
        options: ChangeStreamOptions = .init(),
        @AggregateBuilder build: () -> [AggregateBuilderStage]
    ) async throws -> ChangeStream<Document> {
        try await buildChangeStream(options: options, ofType: Document.self, build: build)
    }
    
    /// Creates a change stream for this collection using the given aggregation pipeline
    /// - Parameters:
    /// - options: The options for this change stream
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
    
    /// Creates a simple change stream for this collection.
    ///
    /// This is a convenience method for creating a change stream without any
    /// aggregation pipeline stages. It watches all changes to the collection.
    ///
    /// ## Basic Usage
    /// ```swift
    /// // Watch all changes
    /// let stream = try await users.watch()
    ///
    /// for try await change in stream {
    ///     print("Operation: \(change.operationType)")
    ///     print("Document: \(change.fullDocument)")
    /// }
    /// ```
    ///
    /// ## With Options
    /// ```swift
    /// var options = ChangeStreamOptions()
    /// options.fullDocument = .updateLookup
    /// options.maxAwaitTimeMS = 1000
    ///
    /// let stream = try await users.watch(options: options)
    /// ```
    ///
    /// ## Type-Safe Changes
    /// ```swift
    /// struct User: Codable {
    ///     let id: ObjectId
    ///     let name: String
    /// }
    ///
    /// let stream = try await users.watch(
    ///     options: options,
    ///     type: User.self
    /// )
    ///
    /// for try await change in stream {
    ///     if let user = change.fullDocument {
    ///         print("User changed: \(user.name)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Implementation Details
    /// - Creates a dedicated connection for the change stream
    /// - Automatically manages cursor lifecycle
    /// - Supports resuming after interruptions
    /// - Can be cancelled using task cancellation
    public func watch(
        options: ChangeStreamOptions = .init()
    ) async throws -> ChangeStream<Document> {
        try await watch(
            options: options,
            type: Document.self
        )
    }
    /// Creates a type-safe change stream for this collection
    ///
    /// This method creates a change stream that decodes changes into a specific type,
    /// providing type-safe access to changed documents.
    ///
    /// - Parameters:
    ///   - options: Options to configure the change stream behavior
    ///   - type: The type to decode changed documents into
    ///   - decoder: Custom BSON decoder to use (optional)
    /// - Returns: A change stream that emits changes with the specified type
    ///
    /// Example:
    /// ```swift
    /// struct User: Codable {
    ///     let id: ObjectId
    ///     let name: String
    ///     let email: String
    /// }
    ///
    /// let stream = try await users.watch(type: User.self)
    /// for try await change in stream {
    ///     if let user = change.fullDocument {
    ///         print("User changed: \(user.name)")
    ///     }
    /// }
    /// ```
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
///
/// Change streams allow applications to track real-time changes to MongoDB data.
/// They provide an asynchronous way to monitor and react to data modifications
/// using Swift's async/await and AsyncSequence.
///
/// ## Basic Usage
/// ```swift
/// // Create a change stream
/// let stream = try await collection.watch()
///
/// // Process changes using async/await
/// for try await change in stream {
///     switch change.operationType {
///     case .insert:
///         print("New document: \(change.fullDocument)")
///     case .update:
///         print("Updated fields: \(change.updateDescription?.updatedFields)")
///     case .delete:
///         print("Deleted document: \(change.documentKey)")
///     default:
///         break
///     }
/// }
/// ```
///
/// ## Type-Safe Changes
/// ```swift
/// struct User: Codable {
///     let id: ObjectId
///     let name: String
///     let email: String
/// }
///
/// // Watch for User document changes
/// let stream = try await users.watch(type: User.self)
///
/// for try await change in stream {
///     if let user = change.fullDocument {
///         print("User modified: \(user.name)")
///     }
/// }
/// ```
///
/// ## Custom Change Handlers
/// ```swift
/// // Process changes with a handler
/// let task = stream.forEach { change in
///     print("Change type: \(change.operationType)")
///     return true // Continue watching
/// }
///
/// // Cancel the stream later
/// task.cancel()
/// ```
///
/// ## Performance Tuning
/// ```swift
/// // Configure intervals between polling
/// var stream = try await collection.watch()
/// stream.setGetMoreInterval(to: .milliseconds(100))
/// ```
///
/// ## Implementation Details
/// - Uses MongoDB's aggregation framework internally
/// - Automatically resumes after network interruptions
/// - Supports filtering and transforming changes
/// - Can be used with or without type decoding
/// - Implements AsyncSequence for easy iteration
///
/// ## Error Handling
/// ```swift
/// do {
///     for try await change in stream {
///         // Process change
///     }
/// } catch {
///     switch error {
///     case let mongoError as MongoError:
///         print("MongoDB error: \(mongoError)")
///     default:
///         print("Unexpected error: \(error)")
///     }
/// }
/// ```
public struct ChangeStream<T: Decodable>: AsyncSequence, Sendable {
    public typealias Notification = ChangeStreamNotification<T>
    public typealias Element = Notification
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

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = Notification
        
        private var iterator: InputCursor.AsyncIterator
        
        init(iterator: InputCursor.AsyncIterator) {
            self.iterator = iterator
        }
        
        public mutating func next() async throws -> Element? {
            try await iterator.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: cursor.makeAsyncIterator())
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
///
/// Change stream notifications provide detailed information about modifications to MongoDB
/// documents. Each notification includes the type of operation, the affected document(s),
/// and additional metadata about the change.
///
/// ## Basic Usage
/// ```swift
/// let stream = try await collection.watch()
///
/// for try await notification in stream {
///     // Access basic information
///     print("Operation: \(notification.operationType)")
///     print("Collection: \(notification.ns.collection)")
///     
///     // Handle different operations
///     switch notification.operationType {
///     case .insert:
///         if let doc = notification.fullDocument {
///             print("New document: \(doc)")
///         }
///     case .update:
///         if let changes = notification.updateDescription {
///             print("Updated fields: \(changes.updatedFields)")
///             print("Removed fields: \(changes.removedFields)")
///         }
///     case .delete:
///         if let key = notification.documentKey {
///             print("Deleted document key: \(key)")
///         }
///     case .drop:
///         print("Collection dropped: \(notification.ns.collection)")
///     default:
///         break
///     }
/// }
/// ```
///
/// ## Operation Types
/// - `insert`: A new document was created
/// - `update`: An existing document was modified
/// - `replace`: An existing document was replaced
/// - `delete`: A document was removed
/// - `drop`: A collection was dropped
/// - `dropDatabase`: A database was dropped
/// - `rename`: A collection was renamed
/// - `invalidate`: The change stream was invalidated
///
/// ## Type-Safe Notifications
/// ```swift
/// struct User: Codable {
///     let id: ObjectId
///     let name: String
///     let email: String
/// }
///
/// let stream = try await users.watch(type: User.self)
///
/// for try await change in stream {
///     if let user = change.fullDocument {
///         print("User modified: \(user.name)")
///     }
/// }
/// ```
///
/// ## Implementation Details
/// - The `_id` field can be used to resume the stream
/// - `documentKey` always contains the `_id` of the modified document
/// - `fullDocument` availability depends on the operation type and options
/// - `updateDescription` is only present for update operations
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
