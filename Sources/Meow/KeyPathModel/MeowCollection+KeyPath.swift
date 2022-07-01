import MongoKitten
import MongoClient

extension MeowCollection where M: KeyPathQueryableModel {
    public func find(
        matching: (QueryMatcher<M>) throws -> Document
    ) rethrows -> MappedCursor<FindQueryBuilder, M> {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
        return raw.find(filter).decode(M.self)
    }
    
    public func findOne(
        matching: (QueryMatcher<M>) throws -> Document
    ) async throws -> M? {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
        return try await raw.findOne(filter, as: M.self)
    }
    
    public func count(
        matching: (QueryMatcher<M>) throws -> Document
    ) async throws -> Int {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
        return try await raw.count(filter)
    }
    
    public func find<MKQ: MongoKittenQuery>(
        matching: (QueryMatcher<M>) throws -> MKQ
    ) rethrows -> MappedCursor<FindQueryBuilder, M> {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher).makeDocument()
        return raw.find(filter).decode(M.self)
    }
    
    public func findOne<MKQ: MongoKittenQuery>(
        matching: (QueryMatcher<M>) throws -> MKQ
    ) async throws -> M? {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher).makeDocument()
        return try await raw.findOne(filter, as: M.self)
    }
    
    public func count<MKQ: MongoKittenQuery>(
        matching: (QueryMatcher<M>) throws -> MKQ
    ) async throws -> Int {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher).makeDocument()
        return try await raw.count(filter)
    }
}

extension Reference where M: KeyPathQueryableModel {
    public func exists(in db: MeowDatabase, where matching: (QueryMatcher<M>) throws -> Document) async throws -> Bool {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
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
    public func resolveIfPresent(in context: MeowDatabase, where matching: (QueryMatcher<M>) throws -> Document) async throws -> M? {
        let base = try "_id" == reference.encodePrimitive()
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
        
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
    public func deleteOne(matching: (QueryMatcher<M>) throws -> Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
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
    public func deleteAll(matching: (QueryMatcher<M>) throws -> Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
        return try await self.deleteAll(where: filter, writeConcern: writeConcern)
    }
    
    @discardableResult
    public func updateOne(matching: (QueryMatcher<M>) throws -> Document, build: (inout ModelUpdateQuery<M>) throws -> ()) async throws -> UpdateReply {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
        
        var update = ModelUpdateQuery<M>()
        try build(&update)
        
        return try await raw.updateOne(where: filter, to: update.makeDocument())
    }
}

public struct ModelUpdateQuery<M: KeyPathQueryableModel & MutableModel> {
    var set = Document()
    var unset = Document()
    var inc = Document()
    
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

public struct ModelGrouper<Base: KeyPathQueryable, Result: KeyPathQueryable> {
    var document = Document()
    
    internal init(_id: Primitive) {
        document["_id"] = _id
    }
    
    public mutating func setAverage<T>(of field: KeyPath<Base, QueryableField<T>>, to result: KeyPath<Result, QueryableField<T>>) {
        let field = FieldPath(components: Base.resolveFieldPath(field))
        let result = FieldPath(components: Result.resolveFieldPath(result))
        document[field.string] = [ "$avg": result.projection ] as Document
    }
}

public struct ModelProjector<Base: KeyPathQueryable, Result: KeyPathQueryable> {
    var projection = Projection()
    
    internal init() {}
    
    public mutating func setField<P: Primitive>(at keyPath: KeyPath<Result, QueryableField<P>>, to newValue: P) {
        let path = FieldPath(components: Result.resolveFieldPath(keyPath))
        projection.addLiteral(newValue, at: path)
    }
    
    public mutating func setField<PE: PrimitiveEncodable>(at keyPath: KeyPath<Result, QueryableField<PE>>, to newValue: PE) throws {
        let path = FieldPath(components: Result.resolveFieldPath(keyPath))
        let newValue = try newValue.encodePrimitive()
        projection.addLiteral(newValue, at: path)
    }
    
    public mutating func excludeField<Value>(at keyPath: KeyPath<Result, QueryableField<Value?>>) {
        let path = FieldPath(components: Result.resolveFieldPath(keyPath))
        projection.exclude(path)
    }
    
    public mutating func includeField<Value>(at keyPath: KeyPath<Result, QueryableField<Value?>>) {
        let path = FieldPath(components: Result.resolveFieldPath(keyPath))
        projection.include(path)
    }
    
    public mutating func moveField<Value>(from base: KeyPath<Base, QueryableField<Value>>, to new: KeyPath<Result, QueryableField<Value>>) {
        let base = FieldPath(components: Base.resolveFieldPath(base))
        let new = FieldPath(components: Result.resolveFieldPath(new))
        projection.rename(base, to: new)
    }
    
    public mutating func moveField<M>(from base: KeyPath<Base, QueryableField<M.Identifier>>, to new: KeyPath<Result, QueryableField<Reference<M>>>) {
        let base = FieldPath(components: Base.resolveFieldPath(base))
        let new = FieldPath(components: Result.resolveFieldPath(new))
        projection.rename(base, to: new)
    }
    
    public mutating func moveField<M>(from base: KeyPath<Base, QueryableField<Reference<M>>>, to new: KeyPath<Result, QueryableField<M.Identifier>>) {
        let base = FieldPath(components: Base.resolveFieldPath(base))
        let new = FieldPath(components: Result.resolveFieldPath(new))
        projection.rename(base, to: new)
    }
    
    public mutating func moveRoot(to path: KeyPath<Result, QueryableField<Base>>) {
        let path = FieldPath(components: Result.resolveFieldPath(path))
        projection.moveRoot(to: path)
    }
}
