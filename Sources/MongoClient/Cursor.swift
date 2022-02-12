import BSON
import NIO
import MongoCore

public final class MongoCursor {
    public private(set) var id: Int64
    private var initialBatch: [Document]?
    internal let closePromise: EventLoopPromise<Void>
    public var closeFuture: EventLoopFuture<Void> { closePromise.futureResult }
    public var isDrained: Bool {
        return self.id == 0 && initialBatch == nil
    }
    public let namespace: MongoNamespace
    public var hoppedEventLoop: EventLoop?
    public let transaction: MongoTransaction?
    public let session: MongoClientSession?
    public var maxTimeMS: Int32?
    public var readConcern: ReadConcern?
    public let connection: MongoConnection

    public init(
        reply: MongoCursorResponse.Cursor,
        in namespace: MongoNamespace,
        connection: MongoConnection,
        hoppedEventLoop: EventLoop? = nil,
        session: MongoClientSession,
        transaction: MongoTransaction?
    ) {
        self.id = reply.id
        self.initialBatch = reply.firstBatch
        self.namespace = namespace
        self.hoppedEventLoop = hoppedEventLoop
        self.connection = connection
        self.session = session
        self.transaction = transaction
        self.closePromise = connection.eventLoop.makePromise()
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
        
        let newCursor = try await connection.executeCodable(
            command,
            decodeAs: GetMoreReply.self,
            namespace: namespace,
            in: self.transaction,
            sessionId: session?.sessionId
        )
        
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
            sessionId: session?.sessionId
        )
        try reply.assertOK()
    }
    
    deinit {
        closePromise.succeed(())
    }
}
