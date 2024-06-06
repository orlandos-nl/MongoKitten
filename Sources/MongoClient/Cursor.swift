import Tracing
import BSON
import NIO
import NIOConcurrencyHelpers
import MongoCore

/// A cursor returned from a query, used to iterate over the results.
/// Used in find, aggregate, and listCollections. This is a reference type, and should be used as such.
///
///    let cursor = collection.find(...)
///    while let doc = try await cursor.next() {
///       print(doc)
///    }
public final class MongoCursor: Sendable {
    private let _id: NIOLockedValueBox<Int64>
    private let _initialBatch: NIOLockedValueBox<[Document]?>
    private let _hoppedEventLoop: NIOLockedValueBox<EventLoop?>
    private let _maxTimeMS: NIOLockedValueBox<Int32?>
    private let _readConcern: NIOLockedValueBox<ReadConcern?>

    /// The id of the cursor, used for `getMore` requests
    public private(set) var id: Int64 {
        get { _id.withLockedValue { $0 } }
        set { _id.withLockedValue { $0 = newValue } }
    }

    private var initialBatch: [Document]? {
        get { _initialBatch.withLockedValue { $0 } }
        set { _initialBatch.withLockedValue { $0 = newValue } }
    }

    internal let closePromise: EventLoopPromise<Void>

    /// A future that will be completed when the cursor is closed
    public var closeFuture: EventLoopFuture<Void> { closePromise.futureResult }

    /// Whether the cursor has been closed, either by the user or by the server
    public var isDrained: Bool {
        return self.id == 0 && initialBatch == nil
    }

    /// The namespace this cursor is reading from
    public let namespace: MongoNamespace

    /// The event loop this cursor is bound to and will return results on
    public var hoppedEventLoop: EventLoop? {
        get { _hoppedEventLoop.withLockedValue { $0 } }
        set { _hoppedEventLoop.withLockedValue { $0 = newValue } }
    }

    /// The transaction this cursor is associated with, if any
    public let transaction: MongoTransaction?

    /// The session this cursor is associated with, if any
    public let session: MongoClientSession?

    /// The maximum amount of time to allow the server to spend on this cursor
    public var maxTimeMS: Int32? {
        get { _maxTimeMS.withLockedValue { $0 } }
        set { _maxTimeMS.withLockedValue { $0 = newValue } }
    }

    /// The read concern to use for this cursor
    public var readConcern: ReadConcern? {
        get { _readConcern.withLockedValue { $0 } }
        set { _readConcern.withLockedValue { $0 = newValue } }
    }

    /// The connection this cursor is using to communicate with the server
    public let connection: MongoConnection

    private let traceLabel: String?
    private let context: ServiceContext?

    public init(
        reply: MongoCursorResponse.Cursor,
        in namespace: MongoNamespace,
        connection: MongoConnection,
        hoppedEventLoop: EventLoop? = nil,
        session: MongoClientSession,
        transaction: MongoTransaction?,
        traceLabel: String? = nil,
        context: ServiceContext? = nil
    ) {
        self._id = NIOLockedValueBox(reply.id)
        self._initialBatch = NIOLockedValueBox(reply.firstBatch)
        self.namespace = namespace
        self._hoppedEventLoop = NIOLockedValueBox(hoppedEventLoop)
        self.connection = connection
        self.session = session
        self.transaction = transaction
        self.closePromise = connection.eventLoop.makePromise()
        self.traceLabel = traceLabel
        self.context = context
        self._maxTimeMS = NIOLockedValueBox(nil)
        self._readConcern = NIOLockedValueBox(nil)
    }

    /// Performs a `GetMore` command on the database, requesting the next batch of items
    public func getMore(batchSize: Int) async throws -> [Document] {
        if let initialBatch = self.initialBatch {
            self.initialBatch = nil
            return initialBatch
        }

        guard !isDrained else {
            throw MongoError(.cannotGetMore, reason: .cursorDrained)
        }

        var command = GetMore(
            cursorId: self.id,
            batchSize: batchSize,
            collection: namespace.collectionName
        )
        command.maxTimeMS = self.maxTimeMS
        command.readConcern = readConcern

        let newCursor = try await withTaskCancellationHandler {
            try await connection.executeCodable(
                command,
                decodeAs: GetMoreReply.self,
                namespace: namespace,
                in: self.transaction,
                sessionId: session?.sessionId,
                traceLabel: "\(traceLabel ?? "UnknownOperation").getMore",
                serviceContext: context
            )
        } onCancel: {
            Task {
                try await self.close()
            }
        }
        self.id = newCursor.cursor.id
        return newCursor.cursor.nextBatch
    }

    /// Closes the cursor stopping any further data from being read
    public func close() async throws {
        let command = KillCursorsCommand([self.id], inCollection: namespace.collectionName)
        self.id = 0
        defer { closePromise.succeed(()) }
        let reply = try await connection.executeEncodable(
            command,
            namespace: namespace,
            in: self.transaction,
            sessionId: session?.sessionId,
            traceLabel: "KillCursor",
            serviceContext: context
        )
        try reply.assertOK()
    }
    
    deinit {
        closePromise.succeed(())
    }
}
