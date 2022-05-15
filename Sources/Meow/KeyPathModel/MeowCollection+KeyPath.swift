import MongoKitten
import MongoClient

extension MeowCollection where M: KeyPathQueryableModel {
    public func find(
        matching: (QueryMatcher<M>) -> Document
    ) -> MappedCursor<FindQueryBuilder, M> {
        let matcher = QueryMatcher<M>()
        let filter = matching(matcher)
        return raw.find(filter).decode(M.self)
    }
    
    public func findOne(
        matching: (QueryMatcher<M>) -> Document
    ) async throws -> M? {
        let matcher = QueryMatcher<M>()
        let filter = matching(matcher)
        return try await raw.findOne(filter, as: M.self)
    }
    
    public func count(
        matching: (QueryMatcher<M>) -> Document
    ) async throws -> Int {
        let matcher = QueryMatcher<M>()
        let filter = matching(matcher)
        return try await raw.count(filter)
    }
    
    public func watch(options: ChangeStreamOptions = .init()) async throws -> ChangeStream<M> {
        return try await raw.watch(options: options, type: M.self)
    }
}

extension MeowCollection where M: MutableModel & KeyPathQueryableModel {
    @discardableResult
    public func deleteOne(where filter: Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await raw.deleteOne(where: filter, writeConcern: writeConcern)
    }
    
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
