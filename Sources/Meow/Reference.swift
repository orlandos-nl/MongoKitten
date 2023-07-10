import Foundation
import MongoKitten
import NIO

/// Reference to a Model by wrapping it's `_id`. Supports wrapping models with any `MeowIdentifier`, including custom `Codable `types.
///
/// Can be used within Vapor's `req.parameters` APIs if `M.Identifier` is `CustomStringConvertible`, like for example `ObjectId`, `UUID` or `String`.
///
/// Example:
///
///     app.get("posts", ":postId") { req -> Post in
///         let postRef: Reference<Post> = try req.parameters.require("postId")
///         let post: Post = try await postRef.resolve(in: req.meow)
///         return post
///     }
public struct Reference<M: ReadableModel>: Resolvable, Hashable, PrimitiveEncodable {
    /// The referenced id
    public let reference: M.Identifier
    
    public typealias Result = M
    
    /// Compares two references to be referring to the same entity
    public static func == (lhs: Reference<M>, rhs: Reference<M>) -> Bool {
        return lhs.reference == rhs.reference
    }
    
    /// Creates a reference to an entity
    public init(to entity: M) {
        reference = entity._id
    }
    
    /// Creates an unchecked reference to an entity
    public init(unsafeTo target: M.Identifier) {
        reference = target
    }
    
    /// Resolves a reference
    public func resolve(in context: MeowDatabase, where query: Document = Document()) async throws -> M {
        guard let referenced = try await resolveIfPresent(in: context, where: query) else {
            throw MeowModelError.referenceError(id: self.reference, type: M.self)
        }
        
        return referenced
    }
    
    /// Resolves a reference, returning `nil` if the referenced object cannot be found
    public func resolveIfPresent(in context: MeowDatabase, where query: Document = Document()) async throws -> M? {
        let base = try "_id" == reference.encodePrimitive()
        
        if query.isEmpty {
            return try await context.collection(for: M.self).findOne(where: base)
        } else {
            let condition = base && query
            return try await context.collection(for: M.self).findOne(where: condition)
        }
    }
    
    /// Checks if the entity exists within `db`
    public func exists(in db: MeowDatabase) async throws -> Bool {
        let _id = try reference.encodePrimitive()
        return try await db[M.self].count(where: "_id" == _id) > 0
    }
    
    /// Checks if the entity exists within `db`, while matching the provided `filter`
    public func exists(in db: MeowDatabase, where filter: Document) async throws -> Bool {
        let _id = try reference.encodePrimitive()
        return try await db[M.self].count(where: "_id" == _id && filter) > 0
    }
    
    /// Checks if the entity exists within `db`, while matching the provided `filter`
    public func exists<Query: MongoKittenQuery>(in db: MeowDatabase, where filter: Query) async throws -> Bool {
        return try await self.exists(in: db, where: filter.makeDocument())
    }
    
    public func encodePrimitive() throws -> Primitive {
        try reference.encodePrimitive()
    }
}

extension Reference where M: MutableModel {
    /// Deletes the target of the reference (making it invalid)
    @discardableResult
    public func deleteTarget(in context: MeowDatabase) async throws-> MeowOperationResult {
        let _id = try reference.encodePrimitive()
        let result = try await context.collection(for: M.self)
            .deleteOne(where: "_id" == _id)
            
        return MeowOperationResult(
            success: result.deletes > 0,
            n: result.deletes,
            writeErrors: result.writeErrors
        )
    }
}

/// A helper postfix operator that creates a `Reference` to `instance`.
/// Similar, but not identifcal, to C-style the Pointer syntax
public postfix func * <M>(instance: M) -> Reference<M> {
    return Reference(to: instance)
}

postfix operator *

extension Reference: Codable {
    public func encode(to encoder: Encoder) throws {
        try reference.encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        reference = try M.Identifier(from: decoder)
    }
}

/// A protocol that provides a uniform syntax for 'resolving' something
public protocol Resolvable {
    associatedtype Result
    associatedtype IfPresentResult
    
    func resolve(in context: MeowDatabase, where query: Document) async throws -> Result
    func resolveIfPresent(in context: MeowDatabase, where query: Document) async throws -> IfPresentResult
}

/// Allows simultaneiously resolving all references in a Set
extension Set: Resolvable where Element: Resolvable {}

/// Allows simultaneiously resolving all references in an Array
extension Array: Resolvable where Element: Resolvable {}
extension Sequence where Element: Resolvable {
    /// Resolves the contained references
    ///
    /// - Parameter context: The context to use for resolving the references
    /// - Throws: When one or more entities fails to resolve
    /// - Returns: All entities - resolved
    public func resolve(in database: MeowDatabase, where query: Document = Document()) async throws -> [Element.Result] {
        var results = [Element.Result]()
        for reference in self {
            try await results.append(reference.resolve(in: database, where: query))
        }
        return results
    }
    
    /// - returns: All entities - resolved or `nil`
    public func resolveIfPresent(in database: MeowDatabase, where query: Document = Document()) async throws -> [Element.IfPresentResult] {
        var results = [Element.IfPresentResult]()
        for reference in self {
            try await results.append(reference.resolveIfPresent(in: database, where: query))
        }
        return results
    }
}

extension Optional: Resolvable where Wrapped: Resolvable {
    public typealias Result = Wrapped.Result?
    public typealias IfPresentResult = Wrapped.IfPresentResult?
    
    public func resolve(in database: MeowDatabase, where query: Document) async throws -> Wrapped.Result? {
        switch self {
        case .none: return nil
        case .some(let value): return try await value.resolve(in: database, where: query)
        }
    }
    
    public func resolveIfPresent(in database: MeowDatabase, where query: Document) async throws -> Wrapped.IfPresentResult? {
        switch self {
        case .none: return nil
        case .some(let value): return try await value.resolveIfPresent(in: database, where: query)
        }
    }
}

extension Reference: CustomStringConvertible where M.Identifier: CustomStringConvertible {
    public var description: String {
        reference.description
    }
}

extension Reference: LosslessStringConvertible where M.Identifier: LosslessStringConvertible {
    public init?(_ description: String) {
        guard let id = M.Identifier(description) else {
            return nil
        }
        
        self.init(unsafeTo: id)
    }
}

extension Reference: RawRepresentable where M.Identifier: RawRepresentable {
    public init?(rawValue: M.Identifier.RawValue) {
        guard let reference = M.Identifier(rawValue: rawValue) else {
            return nil
        }

        self.init(unsafeTo: reference)
    }

    public var rawValue: M.Identifier.RawValue {
        reference.rawValue
    }
}
