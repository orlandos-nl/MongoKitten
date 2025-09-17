import Tracing
import NIO
import NIOConcurrencyHelpers
import MongoClient
import MongoKittenCore

extension MongoCollection {
    /// Finds documents in this collection matching the given query. If no query is given, it returns all documents in the collection.
    /// - Parameter query: The query to match documents against
    /// - Returns: A cursor to iterate over the results
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
    
    /// Finds documents in this collection matching the given query. If no query is given, it returns all documents in the collection.
    /// - Parameter query: The query to match documents against
    /// - Returns: A cursor to iterate over the results
    public func find<Query: MongoKittenQuery>(_ query: Query) -> FindQueryBuilder {
        return find(query.makeDocument())
    }

    /// Finds documents in this collection matching the given query. If no query is given, it returns all documents in the collection. Decodes the results to the given type.
    /// - Parameter query: The query to match documents against
    /// - Returns: A cursor to iterate over the results
    public func find<D: Decodable & Sendable>(_ query: Document = [:], as type: D.Type) -> MappedCursor<FindQueryBuilder, D> {
        return find(query).decode(type)
    }

    /// Finds documents in this collection matching the given query. If no query is given, it returns all documents in the collection. Decodes the results to the given type.
    /// - Parameter query: The query to match documents against
    /// - Returns: A cursor to iterate over the results
    public func find<D: Decodable & Sendable, Query: MongoKittenQuery>(_ query: Query, as type: D.Type) -> MappedCursor<FindQueryBuilder, D> {
        return find(query).decode(type)
    }

    /// Finds the first document in this collection matching the given query. Decodes the result into `D.Type`.
    /// - Parameter query: The query to match documents against
    /// - Parameter type: The type to decode the document to
    /// - Returns: The first document matching the query
    public func findOne<D: Decodable & Sendable>(_ query: Document = [:], as type: D.Type) async throws -> D? {
        return try await find(query).limit(1).decode(type).firstResult()
    }
    
    /// Finds the first document in this collection matching the given query. Decodes the result into `D.Type`.
    /// - Parameter query: The query to match documents against
    /// - Parameter type: The type to decode the document to
    /// - Returns: The first document matching the query
    public func findOne<D: Decodable & Sendable, Query: MongoKittenQuery>(_ query: Query, as type: D.Type) async throws -> D? {
        return try await findOne(query.makeDocument(), as: type)
    }

    /// Finds the first document in this collection matching the given query. If no query is given, it returns the first document in the collection.
    /// - Parameter query: The query to match documents against
    /// - Returns: The first document matching the query
    public func findOne(_ query: Document = [:]) async throws -> Document? {
        return try await find(query).limit(1).firstResult()
    }
    
    /// Finds the first document in this collection matching the given query. If no query is given, it returns the first document in the collection.
    public func findOne<Query: MongoKittenQuery>(_ query: Query) async throws -> Document? {
        return try await findOne(query.makeDocument())
    }
}

/// A builder that constructs a ``FindCommand``, created by running ``MongoCollection/find(_:)-e4ca``
///
/// ```swift
/// let users: MongoCollection = ...
/// let findQueryBuilder = users.find()
/// ```
///
/// Once a find query has been created, it can be modified befure execution.
///
/// ```swift
/// let username = users
///   .find()
///   .project(["username": .included])
/// ```
///
/// Queries are not executed until you either run ``FindQueryBuilder/execute()`` or iterate over the results:
///
/// ```swift
/// for try await document in usernames {
///   print(document)
/// }
/// ```
///
/// You can combine cursors with transformations, similar to `array.map`. ``QueryCursor/decode(_:using:)`` is one such transformation that used `BSONDecoder` to decode the results into a Codable type.
///
/// ```swift
/// struct UserUsername: Codable {
///   // Only the `username` field is projected. The rest will not be available
///   let username: String
/// }
///
/// for try await user in usernames.decode(UserUsername.self) {
///   print(user.username)
/// }
/// ```
public final class FindQueryBuilder: CountableCursor, PaginatableCursor {
    public typealias Element = Document
    
    /// The collection this cursor applies to
    private let makeConnection: @Sendable () async throws -> MongoConnection
    private let _command: NIOLockedValueBox<FindCommand>
    public var command: FindCommand {
        get { _command.withLockedValue { $0} }
        set { _command.withLockedValue { $0 = newValue } }
    }
    private let collection: MongoCollection
    public var isDrained: Bool { false }

    init(command: FindCommand, collection: MongoCollection, makeConnection: @Sendable @escaping () async throws -> MongoConnection, transaction: MongoTransaction? = nil) {
        self._command = NIOLockedValueBox(command)
        self.makeConnection = makeConnection
        self.collection = collection
    }

    public func getConnection() async throws  -> MongoConnection {
        return try await makeConnection()
    }

    @Sendable public func execute() async throws -> FinalizedCursor<FindQueryBuilder> {
        let connection = try await getConnection()
        let findSpan: any Span
        if let context = collection.context {
            findSpan = InstrumentationSystem.tracer.startAnySpan("Find<\(collection.namespace)>", context: context)
        } else {
            findSpan = InstrumentationSystem.tracer.startAnySpan("Find<\(collection.namespace)>")
        }
        let response = try await connection.executeCodable(
            self.command,
            decodeAs: MongoCursorResponse.self,
            namespace: MongoNamespace(to: "$cmd", inDatabase: self.collection.database.name),
            in: self.collection.transaction,
            sessionId: self.collection.sessionId ?? connection.implicitSessionId,
            logMetadata: self.collection.database.logMetadata,
            traceLabel: "Find<\(collection.namespace)>",
            serviceContext: findSpan.context
        )
        
        let cursor = MongoCursor(
            reply: response.cursor,
            in: self.collection.namespace,
            connection: connection,
            session: connection.implicitSession,
            transaction: self.collection.transaction,
            traceLabel: "Find<\(collection.namespace)>",
            context: findSpan.context
        )
        
        return FinalizedCursor(basedOn: self, cursor: cursor)
    }
    
    public func transformElement(_ element: Document) throws -> Document {
        return element
    }

    public func count() async throws -> Int {
        let find = command
        var count = CountCommand(
            on: find.collection,
            where: find.filter
        )
        count.limit = find.limit
        count.skip = find.skip
        count.readConcern = find.readConcern

        let connection = try await makeConnection()
        return try await connection.executeCodable(
            count,
            decodeAs: CountReply.self,
            namespace: self.collection.database.commandNamespace,
            in: self.collection.database.transaction,
            sessionId: self.collection.database.sessionId ?? connection.implicitSessionId,
            logMetadata: self.collection.database.logMetadata
        ).count
    }

    /// Limits the amount of documents returned by this cursor
    public func limit(_ limit: Int) -> FindQueryBuilder {
        self.command.limit = limit
        return self
    }

    /// Skips the given amount of documents before returning the rest
    public func skip(_ skip: Int) -> FindQueryBuilder {
        self.command.skip = skip
        return self
    }

    /// Projects the documents returned by this cursor, limiting the fields returned.
    public func project(_ projection: Projection) -> FindQueryBuilder {
        self.command.projection = projection.document
        return self
    }

    /// Projects the documents returned by this cursor, limiting the fields returned.
    public func project(_ projection: Document) -> FindQueryBuilder {
        self.command.projection = projection
        return self
    }

    /// Sorts the documents returned by this cursor
    public func sort(_ sort: Sorting) -> FindQueryBuilder {
        self.command.sort = sort.document
        return self
    }

    /// Sorts the documents returned by this cursor
    public func sort(_ sort: Document) -> FindQueryBuilder {
        self.command.sort = sort
        return self
    }
    
    /// Sets the batch size for this cursor, limiting the amount of documents returned per roundtrip
    public func batchSize(_ batchSize: Int) -> FindQueryBuilder {
        self.command.batchSize = batchSize
        return self
    }
}
