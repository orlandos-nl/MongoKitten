import NIO
import BSON

internal final class Cursor {
    var id: Int64
    var initialBatch: [Document]?
    var drained: Bool {
        return self.id == 0
    }
    var cancel: (() -> ())?
    let collection: Collection
    
    init(reply: CursorReply, in collection: Collection) {
        self.id = reply.cursor.id
        self.initialBatch = reply.cursor.firstBatch
        self.collection = collection
    }
    
    /// Performs a `GetMore` command on the database, requesting the next batch of items
    func getMore(batchSize: Int) -> EventLoopFuture<CursorBatch<Document>> {
        if let initialBatch = self.initialBatch {
            self.initialBatch = nil
            return collection.eventLoop.newSucceededFuture(result: CursorBatch(batch: initialBatch, isLast: self.drained))
        }
        
        guard !drained else {
            return collection.eventLoop.newFailedFuture(error: MongoKittenError(.cannotGetMore, reason: .cursorDrained))
        }
        
        let command = GetMore(cursorId: self.id, batchSize: batchSize, on: collection)
        return collection.database.session.executeCancellable(command: command).then { cancellableResult in
            self.cancel = cancellableResult.cancel
            
            return cancellableResult.future.map { newCursor in
                return CursorBatch(batch: newCursor.cursor.nextBatch, isLast: newCursor.cursor.id == 0)
            }
        }
    }
    
    deinit {
        cancel?()
    }
    
    func drain() -> EventLoopFuture<[Document]> {
        return CursorDrainer(cursor: self).collectAll()
    }
    
    private final class CursorDrainer {
        var documents = [Document]()
        let cursor: Cursor
        
        init(cursor: Cursor) {
            self.documents = cursor.initialBatch ?? []
            self.cursor = cursor
        }
        
        func collectAll() -> EventLoopFuture<[Document]> {
            return cursor.getMore(batchSize: 101).then { batch -> EventLoopFuture<[Document]> in
                self.documents += batch.batch
                
                if batch.isLast {
                    return self.cursor.collection.eventLoop.newSucceededFuture(result: self.documents)
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
public protocol QueryCursor: class {
    /// The Element type of the cursor
    associatedtype Element
    
    /// The collection this cursor fetches results from
    var collection: Collection { get }
    
    /// The batchSize used for requesting results
    var batchSize: Int { get }
    
    /// Sets the batch size of the cursor to a new value.
    ///
    /// - returns: The cursor, to facilitate chaining multiple method calls.
    @discardableResult func setBatchSize(_ batchSize: Int) -> Self
    
    /// Sets a limit on the number of results
    ///
    /// - returns: The cursor, to facilitate chaining multiple method calls.
    @discardableResult func limit(_ limit: Int) -> Self
    
    /// Sets the amount of results to skip.
    ///
    /// - returns: The cursor, to facilitate chaining multiple method calls.
    @discardableResult func skip(_ skip: Int) -> Self
    
    /// Applies a projection to the cursor.
    ///
    /// - returns: The cursor, to facilitate chaining multiple method calls.
    @discardableResult func project(_ projection: Projection) -> Self
    
    /// Applies a `Sort` to the cursor.
    ///
    /// - returns: The cursor, to facilitate chaining multiple method calls.
    @discardableResult func sort(_ sort: Sort) -> Self
    
    /// Executes the cursor, returning a `FinalizedCursor` after the operation has completed.
    func execute() -> EventLoopFuture<FinalizedCursor<Self>>
    
    /// Transforms a given `Document` to the cursor `Element` type
    func transformElement(_ element: Document) throws -> Element
    
    /// Executes the given `handler` for every element of the cursor.
    ///
    /// - parameter handler: A handler to execute on every result
    /// - returns: A future that resolves when the operation is complete, or fails if an error is thrown
    @discardableResult
    func forEach(handler: @escaping (Element) throws -> Void) -> EventLoopFuture<Void>
    
    /// Executes the given `handler` for every element of the cursor, waiting for each invocations future to complete before heading to the next one
    ///
    /// - parameter handler: A handler to execute on every result
    /// - returns: A future that resolves when the operation is complete, or fails if an error is thrown
    @discardableResult
    func sequentialForEach(handler: @escaping (Element) throws -> EventLoopFuture<Void>) -> EventLoopFuture<Void>
    
    /// Returns a new cursor with the results of mapping the given closure over the cursor's elements. This operation is lazy.
    ///
    /// - parameter transform: A mapping closure. `transform` accepts an element of this cursor as its parameter and returns a transformed value of the same or of a different type.
    func map<E>(transform: @escaping (Element) throws -> E) -> MappedCursor<Self, E>
    
    /// Executes the cursor and returns the first result
    func getFirstResult() -> EventLoopFuture<Element?>
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
        return execute().then { finalizedCursor in
            func nextBatch() -> EventLoopFuture<Void> {
                return finalizedCursor.nextBatch().then { batch in
                    do {
                        var batch = batch
                        
                        guard let element = try batch.nextElement() else {
                            return self.collection.eventLoop.newSucceededFuture(result: ())
                        }
                        
                        var future = element.map(handler)
                        
                        while let element = try batch.nextElement() {
                            future = future.then {
                                return element.map(handler)
                            }
                        }
                        
                        if batch.isLast {
                            return self.collection.eventLoop.newSucceededFuture(result: ())
                        }
                        
                        return nextBatch()
                    } catch {
                        return self.collection.eventLoop.newFailedFuture(error: error)
                    }
                }
            }
            
            return nextBatch()
        }
    }
}

extension QueryCursor {
    /// Executes the given `handler` for every element of the cursor.
    ///
    /// - parameter handler: A handler to execute on every result
    /// - returns: A future that resolves when the operation is complete, or fails if an error is thrown
    @discardableResult
    public func forEach(handler: @escaping (Element) throws -> Void) -> EventLoopFuture<Void> {
        return execute().then { finalizedCursor in
            func nextBatch() -> EventLoopFuture<Void> {
                return finalizedCursor.nextBatch().then { batch in
                    do {
                        var batch = batch
                        
                        while let element = try batch.nextElement(), !finalizedCursor.closed {
                            try handler(element)
                        }
                        
                        if batch.isLast || finalizedCursor.closed {
                            return self.collection.eventLoop.newSucceededFuture(result: ())
                        }
                        
                        return nextBatch()
                    } catch {
                        return self.collection.eventLoop.newFailedFuture(error: error)
                    }
                }
            }
            
            return nextBatch()
        }
    }
    
    @discardableResult
    public func sequentialForEach(handler: @escaping (Element) throws -> EventLoopFuture<Void>) -> EventLoopFuture<Void> {
        return execute().then { finalizedCursor in
            func nextBatch() -> EventLoopFuture<Void> {
                return finalizedCursor.nextBatch().then { batch in
                    do {
                        var batch = batch
                        
                        func next() throws -> EventLoopFuture<Void> {
                            guard let element = try batch.nextElement(), !finalizedCursor.closed else {
                                if batch.isLast || finalizedCursor.closed {
                                    return self.collection.eventLoop.newSucceededFuture(result: ())
                                }
                                
                                return nextBatch()
                            }
                            
                            return try handler(element).then {
                                do {
                                    return try next()
                                } catch {
                                    return self.collection.eventLoop.newFailedFuture(error: error)
                                }
                            }
                        }
                        
                        return try next()
                    } catch {
                        return self.collection.eventLoop.newFailedFuture(error: error)
                    }
                }
            }
            
            return nextBatch()
        }
    }
    
    /// Returns a new cursor with the results of mapping the given closure over the cursor's elements. This operation is lazy.
    ///
    /// - parameter transform: A mapping closure. `transform` accepts an element of this cursor as its parameter and returns a transformed value of the same or of a different type.
    public func map<E>(transform: @escaping (Element) throws -> E) -> MappedCursor<Self, E> {
        return MappedCursor(underlyingCursor: self, transform: transform)
    }
    
    /// Executes the cursor and returns the first result
    /// Always uses a batch size of 1
    public func getFirstResult() -> EventLoopFuture<Element?> {
        let currentBatchSize = self.batchSize
        setBatchSize(1)
        
        defer { setBatchSize(currentBatchSize) }
        return execute().then { finalizedCursor in
            return finalizedCursor.nextBatch()
            }.thenThrowing { batch in
                var batch = batch
                return try batch.nextElement()
        }
    }
    
    /// Executes the cursor and returns all results as an array
    /// Please be aware that this may consume a large amount of memory or time with a large number of results
    public func getAllResults() -> EventLoopFuture<[Element]> {
        return execute().then { finalizedCursor in
            var promise: EventLoopPromise<[Element]> = self.collection.eventLoop.newPromise()
            var results = [Element]()
            
            func nextBatch() {
                finalizedCursor.nextBatch().thenThrowing { batch in
                    var batch = batch
                    
                    while let element = try batch.nextElement() {
                        results.append(element)
                    }
                    
                    guard !batch.isLast else {
                        promise.succeed(result: results)
                        return
                    }
                    
                    nextBatch()
                }.cascadeFailure(promise: promise)
            }
            
            if !finalizedCursor.closed {
                nextBatch()
            }
            
            return promise.futureResult
        }
    }
}

/// A cursor that is based on another cursor
internal protocol CursorBasedOnOtherCursor: QueryCursor {
    associatedtype Base: QueryCursor
    
    var underlyingCursor: Base { get set }
}

/// Includes default implementations that forward to the underlying cursor
extension CursorBasedOnOtherCursor {
    public func setBatchSize(_ batchSize: Int) -> Self {
        _ = underlyingCursor.setBatchSize(batchSize)
        return self
    }
    
    public func limit(_ limit: Int) -> Self {
        _ = underlyingCursor.limit(limit)
        return self
    }
    
    public func skip(_ skip: Int) -> Self {
        _ = underlyingCursor.skip(skip)
        return self
    }
    
    public func sort(_ sort: Sort) -> Self {
        _ = underlyingCursor.sort(sort)
        return self
    }
    
    public func project(_ projection: Projection) -> Self {
        _ = underlyingCursor.project(projection)
        return self
    }
    
    public var batchSize: Int {
        return underlyingCursor.batchSize
    }
    
    public var collection: Collection {
        return underlyingCursor.collection
    }
    
    public func execute() -> EventLoopFuture<FinalizedCursor<Self>> {
        return self.underlyingCursor.execute().map { result in
            return FinalizedCursor(basedOn: self, cursor: result.cursor)
        }
    }
}

/// A concrete cursor, with a corrosponding server side cursor, as the result of a `QueryCursor`
public final class FinalizedCursor<Base: QueryCursor> {
    let base: Base
    let cursor: Cursor
    private(set) var closed = false
    
    init(basedOn base: Base, cursor: Cursor) {
        self.base = base
        self.cursor = cursor
    }
    
    internal func nextBatch() -> EventLoopFuture<CursorBatch<Base.Element>> {
        if closed {
            return cursor.collection.eventLoop.newFailedFuture(error: MongoKittenError(.cannotGetMore, reason: .cursorClosed))
        }
        
        return cursor.getMore(batchSize: base.batchSize).thenThrowing { batch in
            return batch.map(self.base.transformElement)
        }
    }
    
    /// Closes the cursor stopping any further data from being read
    public func close() -> EventLoopFuture<Void> {
        closed = true
        self.cursor.cancel?()
        let command = KillCursorsCommand([self.cursor.id], in: base.collection.namespace)
        return command.execute(on: self.cursor.collection).map { _ in }
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
public final class MappedCursor<Base: QueryCursor, Element>: CursorBasedOnOtherCursor {
    internal typealias Transform<E> = (Base.Element) throws -> E
    
    internal var underlyingCursor: Base
    var transform: Transform<Element>
    
    internal init(underlyingCursor cursor: Base, transform: @escaping Transform<Element>) {
        self.underlyingCursor = cursor
        self.transform = transform
    }
    
    public func transformElement(_ element: Document) throws -> Element {
        let input = try underlyingCursor.transformElement(element)
        return try transform(input)
    }
}
