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
            makeConnection: { [pool] in
                return try await pool.next(for: .basic)
            }
        )
    }
    
    public func find<Query: MongoKittenQuery>(_ query: Query) -> FindQueryBuilder {
        return find(query.makeDocument())
    }

    public func find<D: Decodable>(_ query: Document = [:], as type: D.Type) -> MappedCursor<FindQueryBuilder, D> {
        return find(query).decode(type)
    }

    public func findOne<D: Decodable>(_ query: Document = [:], as type: D.Type) async throws -> D? {
        return try await find(query).limit(1).decode(type).firstResult()
    }
    
    public func findOne<D: Decodable, Query: MongoKittenQuery>(_ query: Query, as type: D.Type) async throws -> D? {
        return try await findOne(query.makeDocument(), as: type)
    }

    public func findOne(_ query: Document = [:]) async throws -> Document? {
        return try await find(query).limit(1).firstResult()
    }
    
    public func findOne<Query: MongoKittenQuery>(_ query: Query) async throws -> Document? {
        return try await findOne(query.makeDocument())
    }
}

/// A builder that constructs a `FindCommand`
public final class FindQueryBuilder: QueryCursor {
    /// The collection this cursor applies to
    private let makeConnection: @Sendable () async throws -> MongoConnection
    public var command: FindCommand
    private let collection: MongoCollection
    public var isDrained: Bool { false }

    init(command: FindCommand, collection: MongoCollection, makeConnection: @Sendable @escaping () async throws -> MongoConnection, transaction: MongoTransaction? = nil) {
        self.command = command
        self.makeConnection = makeConnection
        self.collection = collection
    }

    public func getConnection() async throws  -> MongoConnection {
        return try await makeConnection()
    }

    public func execute() async throws -> FinalizedCursor<FindQueryBuilder> {
        let connection = try await getConnection()
        let response = try await connection.executeCodable(
            self.command,
            decodeAs: MongoCursorResponse.self,
            namespace: MongoNamespace(to: "$cmd", inDatabase: self.collection.database.name),
            in: self.collection.transaction,
            sessionId: self.collection.sessionId ?? connection.implicitSessionId
        )
        let cursor = MongoCursor(
            reply: response.cursor,
            in: self.collection.namespace,
            connection: connection,
            session: connection.implicitSession,
            transaction: self.collection.transaction
        )
        return FinalizedCursor(basedOn: self, cursor: cursor)
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
