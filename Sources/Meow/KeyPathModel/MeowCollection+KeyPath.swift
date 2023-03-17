import MongoKitten
import MongoClient

extension MeowCollection where M: KeyPathQueryableModel {
    /// A helper for `KeyPathQueryableModel` collections that allows type-checked *find* queries to be constructed
    ///
    /// For example, the following query drains all users with the username "Joannis" into an array
    ///
    ///     let users = try await meow[User.self].find { user in
    ///        user.$username == "Joannis"
    ///     }.drain()
    ///
    /// This function is one of two overrides that, together, provide all type of operators to be used in combination with one another
    public func find(
        matching: (QueryMatcher<M>) throws -> Document
    ) rethrows -> MappedCursor<FindQueryBuilder, M> {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
        return raw.find(filter).decode(M.self)
    }
    
    /// A helper for `KeyPathQueryableModel` collections that allows type-checked *findOne* queries to be constructed
    ///
    /// For example, the following query fetches the first user with the username "Joannis"
    ///
    ///     let joannis: User? = try await meow[User.self].findOne { user in
    ///        user.$username == "Joannis"
    ///     }
    ///
    /// This function is one of two overrides that, together, provide all type of operators to be used in combination with one another
    public func findOne(
        matching: (QueryMatcher<M>) throws -> Document
    ) async throws -> M? {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
        return try await raw.findOne(filter, as: M.self)
    }
    
    /// A helper for `KeyPathQueryableModel` collections that allows type-checked *count* queries to be constructed
    ///
    /// For example, the following query counts the amount of admins
    ///
    ///     let admins: Int = try await meow[User.self].findOne { user in
    ///        user.$role == .admin
    ///     }
    ///
    /// This function is one of two overrides that, together, provide all type of operators to be used in combination with one another
    public func count(
        matching: (QueryMatcher<M>) throws -> Document
    ) async throws -> Int {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
        return try await raw.count(filter)
    }
    
    /// A helper for `KeyPathQueryableModel` collections that allows type-checked *find* queries to be constructed
    ///
    /// For example, the following query drains all users with the username "Joannis" into an array
    ///
    ///     let users = try await meow[User.self].find { user in
    ///        user.$username == "Joannis"
    ///     }.drain()
    ///
    /// This function is one of two overrides that, together, provide all type of operators to be used in combination with one another
    public func find<MKQ: MongoKittenQuery>(
        matching: (QueryMatcher<M>) throws -> MKQ
    ) rethrows -> MappedCursor<FindQueryBuilder, M> {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher).makeDocument()
        return raw.find(filter).decode(M.self)
    }
    
    /// A helper for `KeyPathQueryableModel` collections that allows type-checked *findOne* queries to be constructed
    ///
    /// For example, the following query fetches the first user with the username "Joannis"
    ///
    ///     let joannis: User? = try await meow[User.self].findOne { user in
    ///        user.$username == "Joannis"
    ///     }
    ///
    /// This function is one of two overrides that, together, provide all type of operators to be used in combination with one another
    public func findOne<MKQ: MongoKittenQuery>(
        matching: (QueryMatcher<M>) throws -> MKQ
    ) async throws -> M? {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher).makeDocument()
        return try await raw.findOne(filter, as: M.self)
    }
    
    /// A helper for `KeyPathQueryableModel` collections that allows type-checked *count* queries to be constructed
    ///
    /// For example, the following query counts the amount of admins
    ///
    ///     let admins: Int = try await meow[User.self].findOne { user in
    ///        user.$role == .admin
    ///     }
    ///
    /// This function is one of two overrides that, together, provide all type of operators to be used in combination with one another
    public func count<MKQ: MongoKittenQuery>(
        matching: (QueryMatcher<M>) throws -> MKQ
    ) async throws -> Int {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher).makeDocument()
        return try await raw.count(filter)
    }
}

extension Reference where M: KeyPathQueryableModel {
    /// Checks for an entity following this reference exists, while `matching` additional condition(s)
    ///
    /// - Returns: `true` if the entity with this `_id` exists _and_ matches the conditions provided in the `where:` clause
    public func exists(in db: MeowDatabase, where matching: (QueryMatcher<M>) throws -> Document) async throws -> Bool {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
        let _id = try reference.encodePrimitive()
        return try await db[M.self].count(where: "_id" == _id && filter) > 0
    }
    
    /// Resolves a reference, only if the entity matches the provided condition(s)
    ///
    /// - Throws: `MeowModelError.referenceError` if the model could not be found
    /// - Returns: The model `M` if the entity with this `_id` exists _and_ matches the conditions provided in the `where:` clause
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
    /// Deletes (up to) one entity in this collection matching the created filter in the `matching` closure
    ///
    /// - Returns: A `DeleteReply` containing information about the (partial) success of this query
    @discardableResult
    public func deleteOne(matching: (QueryMatcher<M>) throws -> Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
        return try await self.deleteOne(where: filter, writeConcern: writeConcern)
    }
    
    /// Deletes all entities in this collection matching the created filter in the `matching` closure
    ///
    /// - Returns: A `DeleteReply` containing information about the (partial) success of this query
    @discardableResult
    public func deleteAll(matching: (QueryMatcher<M>) throws -> Document, writeConcern: WriteConcern? = nil) async throws -> DeleteReply {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)
        return try await self.deleteAll(where: filter, writeConcern: writeConcern)
    }

    /// Updates one entity matching the filter constructed int the `matching` closure
    @discardableResult
    public func updateOne(matching: (QueryMatcher<M>) throws -> Document, build: (inout ModelUpdateQuery<M>) throws -> ()) async throws -> UpdateReply {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)

        var update = ModelUpdateQuery<M>()
        try build(&update)

        return try await raw.updateOne(where: filter, to: update.makeDocument())
    }

    /// Updates one entity matching the filter constructed int the `matching` closure
    /// The update itself is constructed in the `build` closure using the `ModelUpdateQuery` tpye
    ///
    /// - See: `ModelUpdateQuery` for more information
    @discardableResult
    public func updateOne<MKQ: MongoKittenQuery>(matching: (QueryMatcher<M>) throws -> MKQ, build: (inout ModelUpdateQuery<M>) throws -> ()) async throws -> UpdateReply {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)

        var update = ModelUpdateQuery<M>()
        try build(&update)

        return try await raw.updateOne(where: filter, to: update.makeDocument())
    }

    /// Updates all entities matching the filter constructed int the `matching` closure
    @discardableResult
    public func updateAll(matching: (QueryMatcher<M>) throws -> Document, build: (inout ModelUpdateQuery<M>) throws -> ()) async throws -> UpdateReply {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)

        var update = ModelUpdateQuery<M>()
        try build(&update)

        return try await raw.updateMany(where: filter, to: update.makeDocument())
    }

    /// Updates all entities matching the filter constructed int the `matching` closure
    /// The update itself is constructed in the `build` closure using the `ModelUpdateQuery` tpye
    ///
    /// - See: `ModelUpdateQuery` for more information
    @discardableResult
    public func updateAll<MKQ: MongoKittenQuery>(matching: (QueryMatcher<M>) throws -> MKQ, build: (inout ModelUpdateQuery<M>) throws -> ()) async throws -> UpdateReply {
        let matcher = QueryMatcher<M>()
        let filter = try matching(matcher)

        var update = ModelUpdateQuery<M>()
        try build(&update)

        return try await raw.updateMany(where: filter, to: update.makeDocument())
    }
}

/// A helper type used to construct type-checked atomic updates
public struct ModelUpdateQuery<M: KeyPathQueryableModel & MutableModel> {
    var set = Document()
    var unset = Document()
    var inc = Document()
    var addToSet = [String: [Primitive]]()
    
    internal init() {}
    
    /// Adds an atomic `$set` to the update query that updates the field corresponding to `keyPath` to the `newValue`
    public mutating func setField<P: Primitive>(at keyPath: WritableKeyPath<M, QueryableField<P>>, to newValue: P) {
        let path = M.resolveFieldPath(keyPath).joined(separator: ".")
        set[path] = newValue
    }
    
    public mutating func setField<P: Primitive>(at keyPath: WritableKeyPath<M, QueryableField<P?>>, to newValue: P?) {
        if let newValue = newValue {
            let path = M.resolveFieldPath(keyPath).joined(separator: ".")
            set[path] = newValue
        } else {
            unsetField(at: keyPath)
        }
    }
    
    /// Adds an atomic `$set` to the update query that updates the field corresponding to `keyPath` to the `newValue`
    public mutating func setField<R: RawRepresentable>(at keyPath: WritableKeyPath<M, QueryableField<R>>, to newValue: R) where R.RawValue: Primitive {
        let path = M.resolveFieldPath(keyPath).joined(separator: ".")
        set[path] = newValue.rawValue
    }
    
    public mutating func setField<R: RawRepresentable>(at keyPath: WritableKeyPath<M, QueryableField<R?>>, to newValue: R?) where R.RawValue: Primitive {
        if let newValue = newValue {
            let path = M.resolveFieldPath(keyPath).joined(separator: ".")
            set[path] = newValue.rawValue
        } else {
            unsetField(at: keyPath)
        }
    }
    
    /// Adds an atomic `$unset` to the update query that updates the field corresponding to `keyPath` to be removed
    public mutating func unsetField<Value>(at keyPath: WritableKeyPath<M, QueryableField<Value?>>) {
        let path = M.resolveFieldPath(keyPath).joined(separator: ".")
        unset[path] = ""
    }
    
    /// Adds an atomic `$unset` to the update query that increments the numeric field corresponding to `keyPath` with `newValue` (or 1 by default)
    @available(*, deprecated, message: "Use increment(at:by:) instead")
    public mutating func increment<I: FixedWidthInteger & Primitive>(at keyPath: WritableKeyPath<M, QueryableField<I>>, to newValue: I) {
        let path = M.resolveFieldPath(keyPath).joined(separator: ".")
        inc[path] = newValue
    }

    /// Adds an atomic `$unset` to the update query that increments the numeric field corresponding to `keyPath` with `newValue` (or 1 by default)
    public mutating func increment<I: FixedWidthInteger & Primitive>(at keyPath: WritableKeyPath<M, QueryableField<I>>, by newValue: I = 1) {
        let path = M.resolveFieldPath(keyPath).joined(separator: ".")
        inc[path] = newValue
    }

    /// Adds an atomic `$addToSet` to the update query that increments the numeric field corresponding to `keyPath` with `newValue` (or 1 by default)
    public mutating func addToSet<Value: Hashable & Codable>(at keyPath: WritableKeyPath<M, QueryableField<Set<Value>>>, value: Value) throws {
        let path = M.resolveFieldPath(keyPath).joined(separator: ".")
        let value = try BSONEncoder().encodePrimitive(value) ?? Null()
        if var values = addToSet[path] {
            values.append(value)
            addToSet[path] = values
        } else {
            addToSet[path] = [value]
        }
    }

    /// Adds an atomic `$addToSet` to the update query that increments the numeric field corresponding to `keyPath` with `newValue` (or 1 by default)
    public mutating func addToSet<Value: Primitive & Hashable>(at keyPath: WritableKeyPath<M, QueryableField<Set<Value>>>, value: Value) {
        let path = M.resolveFieldPath(keyPath).joined(separator: ".")
        if var values = addToSet[path] {
            values.append(value)
            addToSet[path] = values
        } else {
            addToSet[path] = [value]
        }
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

        if !addToSet.isEmpty {
            var addToSetDocument = Document()

            for (key, values) in addToSet {
                if values.count == 1 {
                    addToSetDocument[key] = values[0]
                } else {
                    var each = Document(isArray: true)
                    for value in values {
                        each.append(value)
                    }

                    addToSetDocument[key] = [
                        "$each": each
                    ] as Document
                }
            }

            update["$addToSet"] = addToSetDocument
        }
        
        return update
    }
}

/// A helper type used to construct type-checked `$group` queries
///
/// Has two associatedtypes;
/// - `Base` is a `KeyPathQueryableModel`, of which the collection is being grouped
/// - `Result` is the resulting type in which the results are being accumulated
public struct ModelGrouper<Base: KeyPathQueryable, Result: KeyPathQueryable> {
    var document = Document()
    
    internal init(_id: Primitive) {
        document["_id"] = _id
    }
    
    /// Takes the `$avg` of the values in `field`, and accumulates into `result`
    public mutating func setAverage<T>(of field: KeyPath<Base, QueryableField<T>>, to result: KeyPath<Result, QueryableField<T>>) {
        let field = FieldPath(components: Base.resolveFieldPath(field))
        let result = FieldPath(components: Result.resolveFieldPath(result))
        document[field.string] = [ "$avg": result.projection ] as Document
    }
}

/// Used for projecting the values in `Base` into `Result`
public struct ModelProjector<Base: KeyPathQueryable, Result: KeyPathQueryable> {
    var projection = Projection()
    
    internal init() {}
    
    /// Sets the `Result`'s `keyPath` to a constant `newValue`
    public mutating func setField<P: Primitive>(at keyPath: KeyPath<Result, QueryableField<P>>, to newValue: P) {
        let path = FieldPath(components: Result.resolveFieldPath(keyPath))
        projection.addLiteral(newValue, at: path)
    }
    
    /// Sets the `Result`'s `keyPath` to a constant `newValue`
    public mutating func setField<PE: PrimitiveEncodable>(at keyPath: KeyPath<Result, QueryableField<PE>>, to newValue: PE) throws {
        let path = FieldPath(components: Result.resolveFieldPath(keyPath))
        let newValue = try newValue.encodePrimitive()
        projection.addLiteral(newValue, at: path)
    }
    
    /// Explicitly excludes the field at `keyPath` from being projected, used most commonly for `_id`
    public mutating func excludeField<Value>(at keyPath: KeyPath<Result, QueryableField<Value?>>) {
        let path = FieldPath(components: Result.resolveFieldPath(keyPath))
        projection.exclude(path)
    }
    
    /// Includes the field at `keyPath` in the projection, using the same key as before the projection
    public mutating func includeField<Value>(at keyPath: KeyPath<Result, QueryableField<Value?>>) {
        let path = FieldPath(components: Result.resolveFieldPath(keyPath))
        projection.include(path)
    }
    
    /// Moves a field from the `base` KeyPath into the `new` KeyPath found in the `Result` entity
    public mutating func moveField<Value>(from base: KeyPath<Base, QueryableField<Value>>, to new: KeyPath<Result, QueryableField<Value>>) {
        let base = FieldPath(components: Base.resolveFieldPath(base))
        let new = FieldPath(components: Result.resolveFieldPath(new))
        projection.rename(base, to: new)
    }
    
    /// Moves a field from the `base` KeyPath into the `new` KeyPath found in the `Result` entity
    public mutating func moveField<M>(from base: KeyPath<Base, QueryableField<M.Identifier>>, to new: KeyPath<Result, QueryableField<Reference<M>>>) {
        let base = FieldPath(components: Base.resolveFieldPath(base))
        let new = FieldPath(components: Result.resolveFieldPath(new))
        projection.rename(base, to: new)
    }
    
    /// Moves a field from the `base` KeyPath into the `new` KeyPath found in the `Result` entity
    public mutating func moveField<M>(from base: KeyPath<Base, QueryableField<Reference<M>>>, to new: KeyPath<Result, QueryableField<M.Identifier>>) {
        let base = FieldPath(components: Base.resolveFieldPath(base))
        let new = FieldPath(components: Result.resolveFieldPath(new))
        projection.rename(base, to: new)
    }
    
    /// Moves the entire `Base` entity into a value inside `Result`
    public mutating func moveRoot(to path: KeyPath<Result, QueryableField<Base>>) {
        let path = FieldPath(components: Result.resolveFieldPath(path))
        projection.moveRoot(to: path)
    }
    
    /// Moves the entire `Base` entity into a value inside `Result`
    public mutating func moveRoot(to path: KeyPath<Result, QueryableField<Base?>>) {
        let path = FieldPath(components: Result.resolveFieldPath(path))
        projection.moveRoot(to: path)
    }
}

extension MeowCollection where M: KeyPathQueryable {
    /// Allows the construction of type-checked
    public func buildIndexes(@MongoIndexBuilder build: (QueryMatcher<M>) -> _MongoIndexes) async throws {
        let matcher = QueryMatcher<M>()
        try await self.raw.createIndexes(build(matcher).indexes)
    }
}
