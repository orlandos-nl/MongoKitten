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
}

extension Reference where M: KeyPathQueryableModel {
    public func exists(in db: MeowDatabase, where matching: (QueryMatcher<M>) -> Document) async throws -> Bool {
        let matcher = QueryMatcher<M>()
        let filter = matching(matcher)
        let _id = try reference.encodePrimitive()
        return try await db[M.self].count(where: "_id" == _id && filter) > 0
    }
    
    /// Resolves a reference
    public func resolve(in context: MeowDatabase, where matching: (QueryMatcher<M>) -> Document) async throws -> M {
        guard let referenced = try await resolveIfPresent(in: context, where: matching) else {
            throw MeowModelError.referenceError(id: self.reference, type: M.self)
        }
        
        return referenced
    }
    
    /// Resolves a reference, returning `nil` if the referenced object cannot be found
    public func resolveIfPresent(in context: MeowDatabase, where matching: (QueryMatcher<M>) -> Document) async throws -> M? {
        let base = try "_id" == reference.encodePrimitive()
        let matcher = QueryMatcher<M>()
        let filter = matching(matcher)
        
        if filter.isEmpty {
            return try await context.collection(for: M.self).findOne(where: base)
        } else {
            let condition = base && filter
            return try await context.collection(for: M.self).findOne(where: condition)
        }
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
    var unset = Document()
    var inc = Document()
    var error: Error?
    
    internal init() {}
    
    public mutating func setField<P: Primitive>(at keyPath: WritableKeyPath<M, QueryableField<P>>, to newValue: P) {
        let path = M.resolveFieldPath(keyPath).joined(separator: ".")
        set[path] = newValue
    }
    
    public mutating func unsetField<Value>(at keyPath: WritableKeyPath<M, QueryableField<Value?>>) {
        let path = M.resolveFieldPath(keyPath).joined(separator: ".")
        unset[path] = ""
    }
    
    public mutating func increment<I: FixedWidthInteger & Primitive>(at keyPath: WritableKeyPath<M, QueryableField<I>>, to newValue: I = 1) {
        let path = M.resolveFieldPath(keyPath).joined(separator: ".")
        inc[path] = newValue
    }
    
    internal func makeDocument() -> Document {
        var update = Document()
        
        if !set.isEmpty {
            update["$set"] = set
        }
        
        if !unset.isEmpty {
            update["$unset"] = unset
        }
        
        if !inc.isEmpty {
            update["$inc"] = inc
        }
        
        return update
    }
}
