import NIO
import MongoClient
import MongoKittenCore

extension MongoCollection {
    public func find(_ query: Document = [:]) -> FindQueryBuilder {
        return FindQueryBuilder(
            command: FindCommand(
                filter: query,
                inCollection: self.name
            ),
            collection: self,
            connection: pool.next(for: .basic)
        )
    }
    
    public func find<Query: MongoKittenQuery>(_ query: Query) -> FindQueryBuilder {
        return find(query.makeDocument())
    }

    public func findOne<D: Decodable>(_ query: Document = [:], as type: D.Type) -> EventLoopFuture<D?> {
        return find(query).limit(1).decode(type).firstResult()
    }
    
    public func findOne<D: Decodable, Query: MongoKittenQuery>(_ query: Query, as type: D.Type) -> EventLoopFuture<D?> {
        return findOne(query.makeDocument(), as: type)
    }

    public func findOne(_ query: Document = [:]) -> EventLoopFuture<Document?> {
        return find(query).limit(1).firstResult()
    }
    
    public func findOne<Query: MongoKittenQuery>(_ query: Query) -> EventLoopFuture<Document?> {
        return findOne(query.makeDocument())
    }
}

/// A builder that constructs a `FindCommand`
public final class FindQueryBuilder: QueryCursor {
    /// The collection this cursor applies to
    private let connection: EventLoopFuture<MongoConnection>
    public var command: FindCommand
    private let collection: MongoCollection
    public var isDrained: Bool { false }

    public var eventLoop: EventLoop { collection.eventLoop }
    public var hoppedEventLoop: EventLoop? { collection.hoppedEventLoop }

    init(command: FindCommand, collection: MongoCollection, connection: EventLoopFuture<MongoConnection>, transaction: MongoTransaction? = nil) {
        self.command = command
        self.connection = connection
        self.collection = collection
    }

    public func getConnection() -> EventLoopFuture<MongoConnection> {
        return connection
    }

    public func execute() -> EventLoopFuture<FinalizedCursor<FindQueryBuilder>> {
        return connection.flatMap { connection in
            connection.executeCodable(
                self.command,
                namespace: MongoNamespace(to: "$cmd", inDatabase: self.collection.database.name),
                in: self.collection.transaction,
                sessionId: self.collection.sessionId ?? connection.implicitSessionId
            ).flatMapThrowing { reply in
                let response = try MongoCursorResponse(reply: reply)
                let cursor = MongoCursor(
                    reply: response.cursor,
                    in: self.collection.namespace,
                    connection: connection,
                    hoppedEventLoop: self.collection.hoppedEventLoop,
                    session: connection.implicitSession,
                    transaction: self.collection.transaction
                )
                return FinalizedCursor(basedOn: self, cursor: cursor)
            }
        }._mongoHop(to: collection.hoppedEventLoop)
    }
    
    public func transformElement(_ element: Document) throws -> Document {
        return element
    }

    public func limit(_ limit: Int) -> FindQueryBuilder {
        self.command.limit = limit
        return self
    }

    public func skip(_ skip: Int) -> FindQueryBuilder {
        self.command.skip = skip
        return self
    }

    public func project(_ projection: Projection) -> FindQueryBuilder {
        self.command.projection = projection.document
        return self
    }

    public func project(_ projection: Document) -> FindQueryBuilder {
        self.command.projection = projection
        return self
    }

    public func sort(_ sort: Sort) -> FindQueryBuilder {
        self.command.sort = sort.document
        return self
    }

    public func sort(_ sort: Document) -> FindQueryBuilder {
        self.command.sort = sort
        return self
    }
}
