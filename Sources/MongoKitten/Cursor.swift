import NIO
import MongoClient

extension MongoCursor: QueryCursor {
    public var eventLoop: EventLoop { connection.eventLoop }

    public func getConnection() async throws -> MongoConnection {
        connection
    }

    public typealias Element = Document

    public func execute() async throws -> FinalizedCursor<MongoCursor> {
        return FinalizedCursor(basedOn: self, cursor: self)
    }

    public func transformElement(_ element: Document) throws -> Document {
        return element
    }
}

extension MongoCursor {
    /// Collects all results into an array, until the cursor is drained
    public func drain() async throws -> [Document] {
        var documents = [Document]()
        
        while !isDrained {
            documents += try await getMore(batchSize: 101)
        }
        
        return documents
    }
}

struct CursorBatch<Element> {
    typealias Transform = (Document) async throws -> Element

    internal let isLast: Bool
    internal let batch: [Document]
    internal let batchSize: Int
    internal var currentItem = 0
    let transform: Transform

    internal init(batch: [Document], isLast: Bool, transform: @escaping Transform) {
        self.batch = batch
        self.isLast = isLast
        self.transform = transform
        self.batchSize = batch.count
    }

    private init<E>(base: CursorBatch<E>, transform: @escaping (E) async throws -> Element) {
        self.batch = base.batch
        self.isLast = base.isLast
        self.batchSize = base.batchSize
        self.currentItem = base.currentItem
        self.transform = { try await transform(base.transform($0)) }
    }

    mutating func nextElement() async throws -> Element? {
        guard currentItem < batchSize else {
            return nil
        }

        let element = try await transform(batch[currentItem])
        currentItem = currentItem &+ 1
        return element
    }

    func map<T>(_ transform: @escaping (Element) async throws -> T) -> CursorBatch<T> {
        return CursorBatch<T>(base: self, transform: transform)
    }
}

fileprivate extension CursorBatch where Element == Document {
    init(batch: [Document], isLast: Bool) {
        self.init(batch: batch, isLast: isLast) { $0 }
    }
}

/// A cursor with results from a query. Implemented by `FindCursor` and `AggregateCursor`.
/// 
/// Cursors in MongoKitten provide a way to iterate over query results efficiently, fetching documents in batches
/// from the server. This helps manage memory usage when dealing with large result sets.
///
/// ## Basic Usage
/// ```swift
/// // Iterate over results using async/await
/// for try await document in collection.find() {
///     print(document)
/// }
///
/// // Get all results at once (use with caution on large result sets)
/// let allDocuments = try await collection.find().drain()
///
/// // Get just the first result
/// let firstDocument = try await collection.find().firstResult()
/// ```
///
/// ## Transforming Results
/// Cursors can be transformed using `map` or `decode`:
/// ```swift
/// // Map documents to a specific field
/// let names = collection.find().map { doc in
///     doc["name"] as String? ?? ""
/// }
///
/// // Decode documents into a Codable type
/// struct User: Codable {
///     let name: String
///     let age: Int
/// }
/// let users = collection.find().decode(User.self)
/// ```
///
/// ## Error Handling
/// By default, if any document fails to transform (e.g., during decoding),
/// the entire operation fails. You can make transformations failable:
/// ```swift
/// // Only successfully decoded documents will be included
/// let users = try await collection.find().decode(User.self).drain(failable: true)
/// ```
public protocol QueryCursor: Sendable {
    /// The Element type of the cursor
    associatedtype Element

    /// Gets the connection associated with this cursor
    func getConnection() async throws -> MongoConnection

    /// Executes the cursor, returning a `FinalizedCursor` after the operation has completed.
    @Sendable func execute() async throws -> FinalizedCursor<Self>

    /// Transforms a given `Document` to the cursor `Element` type
    func transformElement(_ element: Document) async throws -> Element
}

/// A protocol for cursors that can quickly count their results, without iterating over them.
/// This allows for efficient counting of results using MongoDB's count command rather than
/// iterating through all documents.
///
/// ## Example
/// ```swift
/// let userCount = try await users.find("age" > 18).count()
/// ```
public protocol CountableCursor: QueryCursor {
    /// Counts the number of results in the cursor
    @Sendable func count() async throws -> Int
}

/// A protocol for cursors that can be paginated using `skip` and `limit`.
/// This is useful for implementing pagination in applications.
///
/// ## Example
/// ```swift
/// // Get the second page of 20 items
/// let pageSize = 20
/// let page = 2
/// let results = try await collection.find()
///     .sort("createdAt", .descending)
///     .skip((page - 1) * pageSize)
///     .limit(pageSize)
///     .drain()
/// ```
public protocol PaginatableCursor: QueryCursor {
    /// Limits the number of results returned by the cursor
    /// - Parameter limit: The maximum amount of results to return
    /// - Returns: A new cursor with the limit applied
    func limit(_ limit: Int) -> Self

    /// Skips the given number of results
    /// - Parameter skip: The number of results to skip in the cursor before returning results
    /// - Returns: A new cursor with the skip applied
    func skip(_ skip: Int) -> Self
}

extension QueryCursor {
    /// Executes the given `handler` for every element of the cursor.
    ///
    /// This method allows you to process each document as it's received from the server,
    /// which is memory-efficient for large result sets.
    ///
    /// - Parameters:
    ///   - failable: If `true`, errors during element transformation will be ignored
    ///   - handler: A closure that processes each element
    /// - Returns: A task that completes when all elements have been processed
    ///
    /// ## Example
    /// ```swift
    /// try await users.find().forEach { user in
    ///     print("Processing user: \(user["name"])")
    /// }
    ///
    /// // With error handling for transformations
    /// try await users.find().decode(User.self).forEach(failable: true) { user in
    ///     print("Processing user: \(user.name)")
    /// }
    /// ```
    @discardableResult
    public func forEach(failable: Bool = false, handler: @escaping @Sendable (Element) async throws -> Void) -> Task<Void, Error> {
        Task {
            let finalizedCursor = try await execute()
            
            while !finalizedCursor.isDrained {
                try Task.checkCancellation()
                
                for element in try await finalizedCursor.nextBatch(failable: failable) {
                    try await handler(element)
                }
            }
        }
    }

    /// Returns a new cursor with the results of mapping the given closure over the cursor's elements.
    ///
    /// The transformation is lazy - it only occurs when the cursor is iterated.
    /// This means you can chain multiple transformations without performance penalty.
    ///
    /// - Parameter transform: A mapping closure that transforms each element
    /// - Returns: A new cursor with transformed elements
    ///
    /// ## Example
    /// ```swift
    /// let userAges = users.find().map { doc in
    ///     doc["age"] as Int? ?? 0
    /// }
    ///
    /// for try await age in userAges {
    ///     print("User age: \(age)")
    /// }
    /// ```
    public func map<E>(transform: @escaping @Sendable (Element) async throws -> E) -> MappedCursor<Self, E> {
        return MappedCursor(underlyingCursor: self, transform: transform, failable: false)
    }

    /// Executes the cursor and returns the first result.
    ///
    /// This is optimized to only fetch a single document from the server.
    /// Useful when you only need the first matching document.
    ///
    /// - Returns: The first element, or nil if no results exist
    ///
    /// ## Example
    /// ```swift
    /// // Find the oldest user
    /// let oldestUser = try await users.find()
    ///     .sort("age", .descending)
    ///     .firstResult()
    /// ```
    public func firstResult() async throws -> Element? {
        let finalizedCursor = try await execute()
        return try await finalizedCursor.nextBatch(batchSize: 1).first
    }

    /// Executes the cursor and returns all results as an array.
    ///
    /// - Warning: This method loads all results into memory at once.
    ///   For large result sets, consider using `forEach` or async iteration instead.
    ///
    /// - Parameter failable: If `true`, transformation errors will be ignored
    /// - Returns: Array containing all results
    ///
    /// ## Example
    /// ```swift
    /// // Get all adult users
    /// let adults = try await users.find("age" >= 18).drain()
    ///
    /// // Get all valid user objects, skipping any that fail to decode
    /// let users = try await users.find()
    ///     .decode(User.self)
    ///     .drain(failable: true)
    /// ```
    public func drain(failable: Bool = false) async throws -> [Element] {
        let finalizedCursor = try await execute()
        var results = [Element]()
        
        let iterator = FinalizedCursor.AsyncIterator(
            cursor: finalizedCursor,
            failable: failable
        )
        
        while let result = try await iterator.next() {
            results.append(result)
        }
        
        return results
    }
}

/// A client-side concrete cursor instance with a corresponding server-side cursor.
///
/// This cursor is created when a query is executed and provides methods to iterate
/// over the results in batches. It manages the server-side cursor lifecycle and
/// automatically fetches more results as needed.
///
/// ## Batch Processing
/// ```swift
/// let cursor = try await users.find().execute()
///
/// while !cursor.isDrained {
///     let batch = try await cursor.nextBatch(batchSize: 100)
///     for document in batch {
///         // Process each document
///     }
/// }
///
/// // Don't forget to close the cursor when done early
/// try await cursor.close()
/// ```
///
/// The cursor will be automatically closed when:
/// - All results have been consumed
/// - An error occurs
/// - The cursor is explicitly closed
/// - The task is cancelled
public final class FinalizedCursor<Base: QueryCursor>: Sendable {
    let base: Base

    /// The underlying server-side cursor
    public let cursor: MongoCursor

    /// Whether the cursor has been drained
    public var isDrained: Bool {
        return cursor.isDrained
    }

    init(basedOn base: Base, cursor: MongoCursor) {
        self.base = base
        self.cursor = cursor
    }

    /// Gets the next batch of results from the cursor, defaulting to a batch size of 101.
    /// - parameter batchSize: The number of results to return
    /// - parameter failable: Whether to ignore errors when transforming the results
    /// 
    /// If `failable` is `true`, the returned array will contain only the results that were successfully transformed.
    public func nextBatch(batchSize: Int = 101, failable: Bool = false) async throws -> [Base.Element] {
        let batch = try await cursor.getMore(batchSize: batchSize)

        var elements = [Base.Element]()
        elements.reserveCapacity(batch.count)

        for value in batch {
            do {
                let element = try await self.base.transformElement(value)
                elements.append(element)
            } catch {
                if failable {
                    continue
                } else {
                    throw error
                }
            }
        }

        return elements
    }

    /// Closes the cursor stopping any further data from being read, and cleaning up any resources on the server.
    public func close() async throws {
        if isDrained {
            throw MongoError(.cannotCloseCursor, reason: .alreadyClosed)
        }

        return try await cursor.close()
    }
}

extension QueryCursor where Element == Document {
    /// Generates a `MappedCursor` with decoded instances of `D` as its element type.
    ///
    /// This is a convenient way to decode MongoDB documents into your custom types.
    /// The decoding is performed lazily as documents are fetched from the server.
    ///
    /// - Parameters:
    ///   - type: The `Decodable` type to decode documents into
    ///   - decoder: The decoder to use for decoding documents (defaults to `BSONDecoder()`)
    /// - Returns: A cursor that yields decoded instances of the specified type
    ///
    /// ## Example
    /// ```swift
    /// struct User: Codable {
    ///     let id: ObjectId
    ///     let name: String
    ///     let email: String
    ///     let age: Int
    /// }
    ///
    /// // Find all adult users and decode them
    /// let adults = try await users.find("age" >= 18)
    ///     .decode(User.self)
    ///     .drain()
    ///
    /// // Use a custom decoder
    /// let decoder = BSONDecoder()
    /// decoder.dateDecodingStrategy = .millisecondsSince1970
    ///
    /// let results = try await users.find()
    ///     .decode(User.self, using: decoder)
    ///     .drain()
    /// ```
    public func decode<D: Decodable & Sendable>(_ type: D.Type, using decoder: BSONDecoder = BSONDecoder()) -> MappedCursor<Self, D> {
        return self.map { document in
            return try decoder.decode(D.self, from: document)
        }
    }
}

/// A cursor that transforms the elements of another cursor using a mapping function.
///
/// `MappedCursor` allows you to transform the elements of a cursor without loading
/// all results into memory at once. The transformation is performed lazily as
/// documents are fetched from the server.
///
/// ## Basic Usage
/// ```swift
/// // Map documents to extract specific fields
/// let userNames = users.find().map { doc in
///     doc["name"] as String? ?? "Unknown"
/// }
///
/// // Chain multiple transformations
/// let userAgeGroups = users.find()
///     .map { doc in doc["age"] as Int? ?? 0 }
///     .map { age in
///         switch age {
///         case 0..<18: return "Minor"
///         case 18..<65: return "Adult"
///         default: return "Senior"
///         }
///     }
/// ```
///
/// ## Decoding Documents
/// The most common use of `MappedCursor` is through the `decode` method,
/// which creates a `MappedCursor` that decodes documents into your custom types:
///
/// ```swift
/// struct User: Codable {
///     let id: ObjectId
///     let name: String
///     let age: Int
/// }
///
/// // Find and decode users
/// let adults = try await users.find("age" >= 18)
///     .decode(User.self)
///     .drain()
/// ```
///
/// ## Error Handling
/// By default, if any transformation fails, the entire operation fails.
/// You can make transformations failable using the `failable` parameter
/// in methods like `drain` and `forEach`:
///
/// ```swift
/// // Skip documents that fail to decode
/// let validUsers = try await users.find()
///     .decode(User.self)
///     .drain(failable: true)
///
/// // Process only successfully decoded users
/// try await users.find()
///     .decode(User.self)
///     .forEach(failable: true) { user in
///         print("Processing user: \(user.name)")
///     }
/// ```
public struct MappedCursor<Base: QueryCursor, Element>: QueryCursor {
    internal typealias Transform<E> = @Sendable (Base.Element) async throws -> E

    /// Gets the connection associated with this cursor
    public func getConnection() async throws -> MongoConnection {
        return try await underlyingCursor.getConnection()
    }

    fileprivate var underlyingCursor: Base
    private let transform: Transform<Element>

    internal init(underlyingCursor cursor: Base, transform: @escaping Transform<Element>, failable: Bool) {
        self.underlyingCursor = cursor
        self.transform = transform
    }

    /// Transforms a given `Document` to the cursor `Element` type
    public func transformElement(_ element: Document) async throws -> Element {
        let input = try await underlyingCursor.transformElement(element)
        return try await transform(input)
    }

    /// Executes the cursor, returning a `FinalizedCursor` after the operation has completed.
    /// The returned cursor is used to iterate over the results of the query.
    public func execute() async throws -> FinalizedCursor<MappedCursor<Base, Element>> {
        let result = try await self.underlyingCursor.execute()
        return FinalizedCursor(basedOn: self, cursor: result.cursor)
    }
}

extension MappedCursor: CountableCursor where Base: CountableCursor {
    /// Counts the number of results in the cursor
    public func count() async throws -> Int {
        return try await underlyingCursor.count()
    }
}

extension MappedCursor: PaginatableCursor where Base: PaginatableCursor {
    /// Limits the number of results returned by the cursor
    public func limit(_ limit: Int) -> Self {
        var copy = self
        copy.underlyingCursor = copy.underlyingCursor.limit(limit)
        return self
    }

    /// Skips the given number of results
    public func skip(_ skip: Int) -> Self {
        var copy = self
        copy.underlyingCursor = copy.underlyingCursor.skip(skip)
        return self
    }
}

extension MappedCursor where Base == FindQueryBuilder {
    /// Sorts the results of the cursor
    public func sort(_ sort: Sorting) -> Self {
        underlyingCursor.command.sort = sort.document
        return self
    }

    /// Sorts the results of the cursor
    public func sort(_ sort: Document) -> Self {
        underlyingCursor.command.sort = sort
        return self
    }
}
