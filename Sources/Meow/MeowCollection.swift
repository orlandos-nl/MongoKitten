import MongoKitten
import MongoCore
import NIO

/// A Meow wrapper around `MongoCollection`, that allows you to query the collection while assuming a `Model` format
///
/// Getting a MeowCollection:
///
///     let mongodb: MongoDatabase = mongoCluster["superapp"]
///     let meow = MeowDatabase(mongodb)
///     let users: MeowCollection<User> = meow[User.self]
public struct MeowCollection<M: BaseModel> {
    public let database: MeowDatabase
    public let name: String
    public let raw: MongoCollection
    
    public init(database: MeowDatabase, named name: String) {
        self.database = database
        self.raw = database.raw[name]
        self.name = name
    }
}

extension MeowCollection where M: ReadableModel {
    /// Creates a cursor mapped to Meow model `M`, with the results matching the `filter` using MongoKitten-style API
    ///
    /// If no filter is provided, all entities match.
    ///
    /// Usage:
    ///
    ///     let users: [User] = try await users.find().drain()
    ///
    /// Alternative Usage:
    ///
    ///     let admins: [User] = try await users.find("role" == "admin").drain()
    ///     let adultAdmins: [User] = try await users.find("role" == "admin" && "age" > 18).drain()
    public func find(where filter: Document = [:]) -> MappedCursor<FindQueryBuilder, M> {
        return raw.find(filter).decode(M.self)
    }
    
    /// Creates a cursor mapped to Meow model `M`, with the results matching the `filter` using MongoKitten-style API
    ///
    /// If no filter is provided, all entities match.
    ///
    /// Usage:
    ///
    ///     let users: [User] = try await users.find().drain()
    ///
    /// Alternative Usage:
    ///
    ///     let admins: [User] = try await users.find("role" == "admin").drain()
    ///     let adultAdmins: [User] = try await users.find("role" == "admin" && "age" > 18).drain()
    public func find<Q: MongoKittenQuery>(where filter: Q) -> MappedCursor<FindQueryBuilder, M> {
        return self.find(where: filter.makeDocument())
    }
    
    /// Finds the first model `M` matching `filter` using MongoKitten style API
    ///
    /// Example:
    ///
    ///     let joannis: User? = try await users.findOne("username" == "joannis")
    public func findOne(where filter: Document) async throws -> M? {
        return try await raw.findOne(filter, as: M.self)
    }
    
    /// Finds the first model `M` matching `filter` using MongoKitten style API
    ///
    /// Example:
    ///
    ///     let joannis: User? = try await users.findOne("username" == "joannis")
    public func findOne<Q: MongoKittenQuery>(where filter: Q) async throws -> M? {
        return try await raw.findOne(filter, as: M.self)
    }
    
    /// Counts the amount of models matcihng `filter` using MongoKitten style API
    ///
    /// Example:
    ///
    ///     let adminCount: Int = try await users.count("role" == "admin")
    public func count(where filter: Document) async throws -> Int {
        return try await raw.count(filter)
    }
    
    /// Counts the amount of models matcihng `filter` using MongoKitten style API
    ///
    /// Example:
    ///
    ///     let adminCount: Int = try await users.count("role" == "admin")
    public func count<Q: MongoKittenQuery>(where filter: Q) async throws -> Int {
        return try await self.count(where: filter.makeDocument())
    }
    
    /// Creates a `ChangeStream`,watching for any and all changes within this collection
    ///
    /// - Note: Only works in replica set environments
    public func watch(options: ChangeStreamOptions = .init()) async throws -> ChangeStream<M> {
        return try await raw.watch(options: options, type: M.self, using: M.decoder)
    }
}

extension MeowCollection where M: MutableModel {
    @discardableResult
    public func insert(_ instance: M, writeConcern: WriteConcern? = nil) async throws -> InsertReply {
        return try await raw.insertEncoded(instance, writeConcern: writeConcern)
    }
    
    @discardableResult
    public func insertMany(_ instances: [M], writeConcern: WriteConcern? = nil) async throws -> InsertReply {
        return try await raw.insertManyEncoded(instances, writeConcern: writeConcern)
    }
    
    @discardableResult
    public func upsert(_ instance: M) async throws -> UpdateReply {
        let _id = try instance._id.encodePrimitive()
        return try await raw.upsertEncoded(instance, where: "_id" == _id)
    }
}

extension MeowCollection where M: MutableModel & ReadableModel {
    /// Deletes (up to) one entity in this collection matching the `filter`
    ///
    /// - Returns: A `DeleteReply` containing information about the (partial) success of this query
    @discardableResult
    public func deleteOne(where filter: Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await raw.deleteOne(where: filter, writeConcern: writeConcern)
    }
    
    /// Deletes (up to) one entity in this collection matching the `filter`
    ///
    /// - Returns: A `DeleteReply` containing information about the (partial) success of this query
    @discardableResult
    public func deleteOne<Q: MongoKittenQuery>(where filter: Q, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await self.deleteOne(where: filter.makeDocument(), writeConcern: writeConcern)
    }
    
    @discardableResult
    public func deleteAll(where filter: Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await raw.deleteAll(where: filter, writeConcern: writeConcern)
    }
    
    @discardableResult
    public func deleteAll<Q: MongoKittenQuery>(where filter: Q, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await self.deleteAll(where: filter.makeDocument(), writeConcern: writeConcern)
    }
}

extension MeowCollection where M: KeyPathQueryable {
    public func buildIndexes(@MongoIndexBuilder build: (QueryMatcher<M>) -> _MongoIndexes) async throws {
        let matcher = QueryMatcher<M>()
        try await self.raw.createIndexes(build(matcher).indexes)
    }
}
