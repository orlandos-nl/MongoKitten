import Foundation
import MongoKitten
import NIO

/// Reference to a Model
public struct Reference<M: _Model>: Resolvable {
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
    public func resolve(in context: MeowDatabase, where query: Document = Document()) -> EventLoopFuture<M> {
        return resolveIfPresent(in: context, where: query).flatMapThrowing { referenced in
            guard let referenced = referenced else {
                throw MeowModelError.referenceError(id: self.reference, type: M.self)
            }
            
            return referenced
        }
    }
    
    /// Resolves a reference, returning `nil` if the referenced object cannot be found
    public func resolveIfPresent(in context: MeowDatabase, where query: Document = Document()) -> EventLoopFuture<M?> {
        let base = "_id" == reference
        
        if query.isEmpty {
            return context.collection(for: M.self).findOne(where: base)
        } else {
            let condition = base && query
            return context.collection(for: M.self).findOne(where: condition)
        }
    }
    
    /// Deletes the target of the reference (making it invalid)
    public func deleteTarget(in context: MeowDatabase) -> EventLoopFuture<MeowOperationResult> {
        return context.collection(for: M.self)
            .deleteOne(where: "_id" == reference)
            .map { result in
            return MeowOperationResult(
                success: result.deletes > 0,
                n: result.deletes,
                writeErrors: result.writeErrors
            )
        }
    }
}

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

public protocol Resolvable {
    associatedtype Result
    associatedtype IfPresentResult
    
    func resolve(in context: MeowDatabase, where query: Document) -> EventLoopFuture<Result>
    func resolveIfPresent(in context: MeowDatabase, where query: Document) -> EventLoopFuture<IfPresentResult>
}

//public extension Resolvable where Result: QueryableModel {
//    public func resolve(in context: Context, where query: _ModelQuery<Result>) -> EventLoopFuture<Result> {
//        return self.resolve(in: context, where: query.query)
//    }
//
//    public func resolveIfPresent(in context: Context, where query: _ModelQuery<Result>) -> EventLoopFuture<IfPresentResult> {
//        return self.resolveIfPresent(in: context, where: query.query)
//    }
//}
//
//public extension Resolvable where Result: Sequence, Result.Element: QueryableModel {
//    public func resolve(in context: Context, where query: _ModelQuery<Result.Element>) -> EventLoopFuture<Result> {
//        return self.resolve(in: context, where: query.query)
//    }
//
//    public func resolveIfPresent(in context: Context, where query: _ModelQuery<Result.Element>) -> EventLoopFuture<IfPresentResult> {
//        return self.resolveIfPresent(in: context, where: query.query)
//    }
//}

extension Set: Resolvable where Element: Resolvable {}
extension Array: Resolvable where Element: Resolvable {}
extension Sequence where Element: Resolvable {
    /// Resolves the contained references
    ///
    /// - parameter context: The context to use for resolving the references
    /// - returns: An EventLoopFuture that completes with an array of
    public func resolve(in database: MeowDatabase, where query: Document = Document()) -> EventLoopFuture<[Element.Result]> {
        let futures = self.map { $0.resolve(in: database, where: query) }
        return EventLoopFuture.reduce(into: [], futures, on: database.eventLoop) { array, resolved in
            array.append(resolved)
        }
    }
    
    public func resolveIfPresent(in database: MeowDatabase, where query: Document = Document()) -> EventLoopFuture<[Element.IfPresentResult]> {
        let futures = self.map { $0.resolveIfPresent(in: database, where: query) }
        return EventLoopFuture.reduce(into: [], futures, on: database.eventLoop) { array, resolved in
            array.append(resolved)
        }
    }
}

extension Optional: Resolvable where Wrapped: Resolvable {
    public typealias Result = Wrapped.Result?
    public typealias IfPresentResult = Wrapped.IfPresentResult?
    
    public func resolve(in database: MeowDatabase, where query: Document) -> EventLoopFuture<Wrapped.Result?> {
        switch self {
        case .none: return database.eventLoop.makeSucceededFuture(nil)
        case .some(let value): return value.resolve(in: database, where: query).map { $0 }
        }
    }
    
    public func resolveIfPresent(in database: MeowDatabase, where query: Document) -> EventLoopFuture<Wrapped.IfPresentResult?> {
        switch self {
        case .none: return database.eventLoop.makeSucceededFuture(nil)
        case .some(let value): return value.resolveIfPresent(in: database, where: query).map { $0 }
        }
    }
}
