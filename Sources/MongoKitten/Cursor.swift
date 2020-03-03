import NIO
import MongoClient

extension MongoCursor: QueryCursor {
    public var eventLoop: EventLoop { connection.eventLoop }

    public func getConnection() -> EventLoopFuture<MongoConnection> {
        return connection.eventLoop.makeSucceededFuture(connection)
    }

    public typealias Element = Document

    public func execute() -> EventLoopFuture<FinalizedCursor<MongoCursor>> {
        return connection.eventLoop.makeSucceededFuture(FinalizedCursor(basedOn: self, cursor: self))
    }

    public func transformElement(_ element: Document) throws -> Document {
        return element
    }
}

extension MongoCursor {
    public func drain() -> EventLoopFuture<[Document]> {
        return CursorDrainer(cursor: self).collectAll()
    }

    private final class CursorDrainer {
        var documents = [Document]()
        let cursor: MongoCursor

        init(cursor: MongoCursor) {
            self.cursor = cursor
        }

        func collectAll() -> EventLoopFuture<[Document]> {
            return cursor.getMore(batchSize: 101).flatMap { batch -> EventLoopFuture<[Document]> in
                self.documents += batch

                if self.cursor.isDrained {
                    return self.cursor.connection.eventLoop.makeSucceededFuture(self.documents)
                }

                return self.collectAll()
            }
        }
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

    var eventLoop: EventLoop { get }
    var hoppedEventLoop: EventLoop? { get }

    func getConnection() -> EventLoopFuture<MongoConnection>

    /// Executes the cursor, returning a `FinalizedCursor` after the operation has completed.
    func execute() -> EventLoopFuture<FinalizedCursor<Self>>

    /// Transforms a given `Document` to the cursor `Element` type
    func transformElement(_ element: Document) throws -> Element
}

extension QueryCursor {
    /// Helper method for executing a closure on each element of a cursor whose element is itself a future.
    ///
    /// - parameter handler: A closure that will be executed on the result of every succeeded future
    /// - returns: A future that succeeds when the operation is completed
    @discardableResult
    public func forEachFuture<T>(
        handler: @escaping (T) -> Void
    ) -> EventLoopFuture<Void> where Element == EventLoopFuture<T> {
        return execute().flatMap { finalizedCursor in
            func nextBatch() -> EventLoopFuture<Void> {
                return finalizedCursor.nextBatch().flatMap { batch in
                    guard let document = batch.first else {
                        return self.eventLoop.makeSucceededFuture(())
                    }

                    var future = document.map(handler)

                    for i in 1..<batch.count {
                        let element = batch[i]
                        future = future.flatMap {
                            return element.map(handler)
                        }
                    }

                    if finalizedCursor.isDrained {
                        return self.eventLoop.makeSucceededFuture(())
                    }

                    return nextBatch()
                }
            }

            return nextBatch()
        }._mongoHop(to: self.hoppedEventLoop)
    }
}

extension QueryCursor {
    /// Executes the given `handler` for every element of the cursor.
    ///
    /// - parameter handler: A handler to execute on every result
    /// - returns: A future that resolves when the operation is complete, or fails if an error is thrown
    @discardableResult
    public func forEach(handler: @escaping (Element) throws -> Void) -> EventLoopFuture<Void> {
        return execute().flatMap { finalizedCursor in
            func nextBatch() -> EventLoopFuture<Void> {
                return finalizedCursor.nextBatch().flatMap { batch in
                    do {
                        for element in batch {
                            try handler(element)
                        }

                        if finalizedCursor.isDrained {
                            return self.eventLoop.makeSucceededFuture(())
                        }

                        return nextBatch()
                    } catch {
                        return self.eventLoop.makeFailedFuture(error)
                    }
                }
            }

            return nextBatch()
        }._mongoHop(to: self.hoppedEventLoop)
    }

    @discardableResult
    public func sequentialForEach(handler: @escaping (Element) throws -> EventLoopFuture<Void>) -> EventLoopFuture<Void> {
        return execute().flatMap { finalizedCursor in
            func nextBatch() -> EventLoopFuture<Void> {
                return finalizedCursor.nextBatch().flatMap { batch in
                    do {
                        var batch = batch.makeIterator()

                        func next() throws -> EventLoopFuture<Void> {
                            guard let element = batch.next() else {
                                if finalizedCursor.isDrained {
                                    return self.eventLoop.makeSucceededFuture(())
                                }

                                return nextBatch()
                            }

                            return try handler(element).flatMap {
                                do {
                                    return try next()
                                } catch {
                                    return self.eventLoop.makeFailedFuture(error)
                                }
                            }
                        }

                        return try next()
                    } catch {
                        return self.eventLoop.makeFailedFuture(error)
                    }
                }
            }

            return nextBatch()._mongoHop(to: self.hoppedEventLoop)
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
    public func firstResult() -> EventLoopFuture<Element?> {
        return execute().flatMap { finalizedCursor in
            return finalizedCursor.nextBatch(batchSize: 1)
        }.flatMapThrowing { batch in
            return batch.first
        }._mongoHop(to: self.hoppedEventLoop)
    }

    /// Executes the cursor and returns all results as an array
    /// Please be aware that this may consume a large amount of memory or time with a large number of results
    public func allResults(failable: Bool = false) -> EventLoopFuture<[Element]> {
        return execute().flatMap { finalizedCursor in
            var promise = self.eventLoop.makePromise(of: [Element].self)
            var results = [Element]()

            func nextBatch() {
                finalizedCursor.nextBatch(failable: failable).flatMapThrowing { batch in
                    results.append(contentsOf: batch)

                    if finalizedCursor.isDrained {
                        promise.succeed(results)
                    } else {
                        nextBatch()
                    }
                }.cascadeFailure(to: promise)
            }

            nextBatch()

            return promise.futureResult._mongoHop(to: self.hoppedEventLoop)
        }
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

    public func nextBatch(batchSize: Int = 101, failable: Bool = false) -> EventLoopFuture<[Base.Element]> {
        return cursor.getMore(batchSize: batchSize)._mongoHop(to: cursor.hoppedEventLoop).flatMapThrowing { batch in
            if failable {
                return batch.compactMap { element in
                    return try? self.base.transformElement(element)
                }
            } else {
                return try batch.map(self.base.transformElement)
            }
        }._mongoHop(to: cursor.hoppedEventLoop)
    }

    /// Closes the cursor stopping any further data from being read
    public func close() -> EventLoopFuture<Void> {
        if isDrained {
            return cursor.connection.eventLoop.makeFailedFuture(MongoError(.cannotCloseCursor, reason: .alreadyClosed))
        }

        return cursor.close()._mongoHop(to: cursor.hoppedEventLoop)
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

    public func getConnection() -> EventLoopFuture<MongoConnection> {
        return underlyingCursor.getConnection()
    }

    public var eventLoop: EventLoop { underlyingCursor.eventLoop }
    public var hoppedEventLoop: EventLoop? { underlyingCursor.hoppedEventLoop }

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

    public func execute() -> EventLoopFuture<FinalizedCursor<MappedCursor<Base, Element>>> {
        return self.underlyingCursor.execute().map { result in
            return FinalizedCursor(basedOn: self, cursor: result.cursor)
        }._mongoHop(to: self.hoppedEventLoop)
    }
}
