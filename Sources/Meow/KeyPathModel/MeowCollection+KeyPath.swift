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
    public func deleteOne(matching: (QueryMatcher<M>) -> Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        let matcher = QueryMatcher<M>()
        let filter = matching(matcher)
        return try await self.deleteOne(where: filter, writeConcern: writeConcern)
    }
    
    @discardableResult
    public func deleteAll(where filter: Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await raw.deleteAll(where: filter, writeConcern: writeConcern)
    }
    
    @discardableResult
    public func deleteAll<Q: MongoKittenQuery>(where filter: Q, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        return try await self.deleteAll(where: filter.makeDocument(), writeConcern: writeConcern)
    }
    
    @discardableResult
    public func deleteAll(matching: (QueryMatcher<M>) -> Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        let matcher = QueryMatcher<M>()
        let filter = matching(matcher)
        return try await self.deleteAll(where: filter, writeConcern: writeConcern)
    }
    
    @discardableResult
    public func updateOne(matching: (QueryMatcher<M>) -> Document, build: (inout ModelUpdateQuery<M>) throws -> ()) async throws -> UpdateReply {
        let matcher = QueryMatcher<M>()
        let filter = matching(matcher)
        
        var update = ModelUpdateQuery<M>()
        try build(&update)
        
        return try await raw.updateOne(where: filter, to: update.makeDocument())
    }
}

public struct ModelUpdateQuery<M: KeyPathQueryableModel & MutableModel> {
    var set = Document()
    var inc = Document()
    var error: Error?
    
    internal init() {}
    
    public mutating func setField<P: Primitive>(at keyPath: WritableKeyPath<M, QueryableField<P>>, to newValue: P) throws {
        let path = try M.resolveFieldPath(keyPath).joined(separator: ".")
        set[path] = newValue
    }
    
    public mutating func increment<I: FixedWidthInteger & Primitive>(at keyPath: WritableKeyPath<M, QueryableField<I>>, to newValue: I = 1) throws {
        let path = try M.resolveFieldPath(keyPath).joined(separator: ".")
        inc[path] = newValue
    }
    
    internal func makeDocument() -> Document {
        var update = Document()
        
        if !set.isEmpty {
            update["$set"] = set
        }
        
        if !inc.isEmpty {
            update["$inc"] = inc
        }
        
        return update
    }
}
