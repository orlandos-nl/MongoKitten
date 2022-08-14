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
    typealias Transform = (Document) throws -> Element

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

    private init<E>(base: CursorBatch<E>, transform: @escaping (E) throws -> Element) {
        self.batch = base.batch
        self.isLast = base.isLast
        self.batchSize = base.batchSize
        self.currentItem = base.currentItem
        self.transform = { try transform(base.transform($0)) }
    }

    mutating func nextElement() throws -> Element? {
        guard currentItem < batchSize else {
            return nil
        }

        let element = try transform(batch[currentItem])
        currentItem = currentItem &+ 1
        return element
    }

    func map<T>(_ transform: @escaping (Element) throws -> T) -> CursorBatch<T> {
        return CursorBatch<T>(base: self, transform: transform)
    }
}

fileprivate extension CursorBatch where Element == Document {
    init(batch: [Document], isLast: Bool) {
        self.init(batch: batch, isLast: isLast) { $0 }
    }
}

/// A cursor with results from a query. Implemented by `FindCursor` and `AggregateCursor`.
public protocol QueryCursor {
    /// The Element type of the cursor
    associatedtype Element

    func getConnection() async throws -> MongoConnection

    /// Executes the cursor, returning a `FinalizedCursor` after the operation has completed.
    func execute() async throws -> FinalizedCursor<Self>

    /// Transforms a given `Document` to the cursor `Element` type
    func transformElement(_ element: Document) throws -> Element
}

extension QueryCursor {
    /// Executes the given `handler` for every element of the cursor.
    ///
    /// - parameter handler: A handler to execute on every result
    /// - returns: A future that resolves when the operation is complete, or fails if an error is thrown
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

    /// Returns a new cursor with the results of mapping the given closure over the cursor's elements. This operation is lazy.
    ///
    /// - parameter transform: A mapping closure. `transform` accepts an element of this cursor as its parameter and returns a transformed value of the same or of a different type.
    public func map<E>(transform: @escaping (Element) throws -> E) -> MappedCursor<Self, E> {
        return MappedCursor(underlyingCursor: self, transform: transform, failable: false)
    }

    /// Executes the cursor and returns the first result
    /// Always uses a batch size of 1
    public func firstResult() async throws -> Element? {
        let finalizedCursor = try await execute()
        return try await finalizedCursor.nextBatch(batchSize: 1).first
    }

    /// Executes the cursor and returns all results as an array
    /// Please be aware that this may consume a large amount of memory or time with a large number of results
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

/// A concrete cursor, with a corrosponding server side cursor, as the result of a `QueryCursor`
public final class FinalizedCursor<Base: QueryCursor> {
    let base: Base
    public let cursor: MongoCursor
    public var isDrained: Bool {
        return cursor.isDrained
    }

    init(basedOn base: Base, cursor: MongoCursor) {
        self.base = base
        self.cursor = cursor
    }

    public func nextBatch(batchSize: Int = 101, failable: Bool = false) async throws -> [Base.Element] {
        let batch = try await cursor.getMore(batchSize: batchSize)
        
        if failable {
            return batch.compactMap { element in
                return try? self.base.transformElement(element)
            }
        } else {
            return try batch.map(self.base.transformElement)
        }
    }

    /// Closes the cursor stopping any further data from being read
    public func close() async throws {
        if isDrained {
            throw MongoError(.cannotCloseCursor, reason: .alreadyClosed)
        }

        return try await cursor.close()
    }
}

extension QueryCursor where Element == Document {
    /// Generates a `MappedCursor` with decoded instances of `D` as its element type, using the given `decoder`.
    public func decode<D: Decodable>(_ type: D.Type, using decoder: BSONDecoder = BSONDecoder()) -> MappedCursor<Self, D> {
        return self.map { document in
            return try decoder.decode(D.self, from: document)
        }
    }
}

/// A cursor that is the result of mapping another cursor
public struct MappedCursor<Base: QueryCursor, Element>: QueryCursor {
    internal typealias Transform<E> = (Base.Element) throws -> E

    public func getConnection() async throws -> MongoConnection {
        return try await underlyingCursor.getConnection()
    }

    private let underlyingCursor: Base
    private let transform: Transform<Element>

    internal init(underlyingCursor cursor: Base, transform: @escaping Transform<Element>, failable: Bool) {
        self.underlyingCursor = cursor
        self.transform = transform
    }

    public func transformElement(_ element: Document) throws -> Element {
        let input = try underlyingCursor.transformElement(element)
        return try transform(input)
    }

    public func execute() async throws -> FinalizedCursor<MappedCursor<Base, Element>> {
        let result = try await self.underlyingCursor.execute()
        return FinalizedCursor(basedOn: self, cursor: result.cursor)
    }
}

extension MappedCursor where Base == FindQueryBuilder {
    public func limit(_ limit: Int) -> Self {
        underlyingCursor.command.limit = limit
        return self
    }

    public func skip(_ skip: Int) -> Self {
        underlyingCursor.command.skip = skip
        return self
    }

    public func sort(_ sort: Sorting) -> Self {
        underlyingCursor.command.sort = sort.document
        return self
    }

    public func sort(_ sort: Document) -> Self {
        underlyingCursor.command.sort = sort
        return self
    }
}
