import MongoCore
import MongoKittenCore

/// A result builder for creating MongoDB indexes in a type-safe and declarative way.
///
/// The `MongoIndexBuilder` provides a DSL-like syntax for creating multiple indexes
/// at once. It supports all MongoDB index types and allows for flexible index configuration.
///
/// ## Basic Usage
/// ```swift
/// try await users.buildIndexes {
///     // Single field index
///     SortedIndex(named: "age-index", field: "age")
///
///     // Unique index
///     UniqueIndex(named: "email-index", field: "email")
///
///     // Compound index
///     SortedIndex(
///         by: ["country": .ascending, "age": .descending],
///         named: "country-age-index"
///     )
/// }
/// ```
///
/// ## Index Types
/// The builder supports several index types:
/// - `SortedIndex`: Basic index for fast queries and sorting
/// - `UniqueIndex`: Ensures field values are unique across documents
/// - `TTLIndex`: Automatically removes documents after a specified time
/// - `TextScoreIndex`: Enables full-text search capabilities
///
/// ## Index Options
/// Indexes can be customized with additional options:
/// ```swift
/// try await users.buildIndexes {
///     // Create a unique index with custom collation
///     SortedIndex(named: "name-index", field: "name")
///         .unique()
///         .collation(Collation(locale: "en"))
///
///     // Create a TTL index that expires documents after 24 hours
///     SortedIndex(named: "temp-index", field: "createdAt")
///         .ttl(seconds: 24 * 60 * 60)
/// }
/// ```
@resultBuilder
public struct MongoIndexBuilder {
    public static func buildBlock() -> _MongoIndexes {
        return _MongoIndexes(indexes: [])
    }
    
    public static func buildBlock(_ content: _MongoIndex) -> _MongoIndexes {
        .init(indexes: [content.index])
    }
    
    public static func buildBlock(_ content: _MongoIndex...) -> _MongoIndexes {
        return _MongoIndexes(indexes: content.reduce([], { $0 + [$1.index] }))
    }
    
    public static func buildIf(_ content: _MongoIndex?) -> _MongoIndexes {
        if let content = content {
            return .init(indexes: [content.index])
        }
        
        return _MongoIndexes(indexes: [])
    }
    
    public static func buildEither(first: _MongoIndex) -> _MongoIndexes {
        .init(indexes: [first.index])
    }
    
    public static func buildEither(second: _MongoIndex) -> _MongoIndexes {
        .init(indexes: [second.index])
    }
}

/// A container for multiple index specifications.
///
/// This type is used internally by the `MongoIndexBuilder` to collect
/// multiple index specifications that will be created together.
public struct _MongoIndexes {
    public private(set) var indexes: [CreateIndexes.Index]
}

/// A single index specification that can be customized with additional options.
///
/// This type represents a single index to be created and provides methods
/// to configure the index with various options like uniqueness, TTL, and collation.
///
/// ## Example
/// ```swift
/// // Create a unique index with custom collation
/// let index = SortedIndex(named: "name-index", field: "name")
///     .unique()
///     .collation(Collation(locale: "en"))
///
/// // Create a TTL index
/// let ttlIndex = SortedIndex(named: "temp-index", field: "createdAt")
///     .ttl(seconds: 3600) // Expire after 1 hour
/// ```
public struct _MongoIndex {
    internal var index: CreateIndexes.Index
    
    /// Makes the index enforce unique values for the indexed field(s).
    ///
    /// When an index is unique, MongoDB will reject documents that have
    /// duplicate values for the indexed field(s).
    ///
    /// - Parameter isUnique: Whether the index should enforce uniqueness
    /// - Returns: The modified index specification
    ///
    /// ## Example
    /// ```swift
    /// try await users.buildIndexes {
    ///     SortedIndex(named: "email-index", field: "email")
    ///         .unique() // No two users can have the same email
    /// }
    /// ```
    public func unique(_ isUnique: Bool = true) -> _MongoIndex {
        var copy = self
        copy.index.unique = isUnique
        return copy
    }
    
    /// Configures the index as a TTL (Time-To-Live) index.
    ///
    /// TTL indexes automatically remove documents after a specified number
    /// of seconds. This is useful for session data, temporary logs, etc.
    ///
    /// - Parameter seconds: The number of seconds after which documents should be removed
    /// - Returns: The modified index specification
    ///
    /// ## Example
    /// ```swift
    /// try await sessions.buildIndexes {
    ///     SortedIndex(named: "session-ttl", field: "lastAccess")
    ///         .ttl(seconds: 30 * 60) // Sessions expire after 30 minutes
    /// }
    /// ```
    /// 
    /// - Note: TTL indexes can only be created on fields containing dates
    public func ttl(seconds: Int?) -> _MongoIndex {
        var copy = self
        copy.index.expireAfterSeconds = seconds
        return copy
    }
    
    /// Sets the collation for the index.
    ///
    /// Collation allows you to specify language-specific rules for string
    /// comparison, such as rules for lettercase and accent marks.
    ///
    /// - Parameter collation: The collation rules to use for this index
    /// - Returns: The modified index specification
    ///
    /// ## Example
    /// ```swift
    /// try await users.buildIndexes {
    ///     SortedIndex(named: "name-index", field: "name")
    ///         .collation(Collation(
    ///             locale: "en",
    ///             strength: .secondary
    ///         ))
    /// }
    /// ```
    public func collation(_ collation: Collation?) -> _MongoIndex {
        var copy = self
        copy.index.collation = collation
        return copy
    }
}

/// Creates a basic index for fast queries and sorting.
///
/// - Parameters:
///   - name: A unique name for the index
///   - field: The field to index
///   - order: The sort order for the index (default: .ascending)
/// - Returns: An index specification
///
/// ## Example
/// ```swift
/// try await users.buildIndexes {
///     // Simple ascending index
///     SortedIndex(named: "age-index", field: "age")
///
///     // Descending index
///     SortedIndex(named: "date-index", field: "createdAt", order: .descending)
/// }
/// ```
public func SortedIndex(
    named name: String,
    field: String,
    order: Sorting.Order = .ascending
) -> _MongoIndex {
    // Ascending or descending doesn't matter on one index
    _MongoIndex(index: CreateIndexes.Index(named: name, key: field, order: order))
}

/// Creates a compound index on multiple fields.
///
/// - Parameters:
///   - spec: The fields and their sort orders to index
///   - name: A unique name for the index
/// - Returns: An index specification
///
/// ## Example
/// ```swift
/// try await users.buildIndexes {
///     // Index on location (ascending) and age (descending)
///     SortedIndex(
///         by: ["location": .ascending, "age": .descending],
///         named: "location-age-index"
///     )
/// }
/// ```
public func SortedIndex(
    by spec: Sorting,
    named name: String
) -> _MongoIndex {
    // Ascending or descending doesn't matter on one index
    _MongoIndex(index: CreateIndexes.Index(named: name, keys: spec.document))
}

/// Creates a unique index that enforces unique values for the indexed field(s).
///
/// - Parameters:
///   - name: A unique name for the index
///   - field: The field that must have unique values
///   - order: The sort order for the index (default: .ascending)
/// - Returns: An index specification
///
/// ## Example
/// ```swift
/// try await users.buildIndexes {
///     // No two users can have the same email
///     UniqueIndex(named: "email-index", field: "email")
///
///     // Compound unique index
///     UniqueIndex(named: "org-role", field: ["orgId", "role"])
/// }
/// ```
public func UniqueIndex(
    named name: String,
    field: String,
    order: Sorting.Order = .ascending
) -> _MongoIndex {
    SortedIndex(named: name, field: field, order: order)
        .unique()
}

/// Creates a TTL (Time-To-Live) index that automatically removes documents.
///
/// - Parameters:
///   - name: A unique name for the index
///   - field: The date field to use for expiration
///   - seconds: The number of seconds after which documents should be removed
/// - Returns: An index specification
///
/// ## Example
/// ```swift
/// try await sessions.buildIndexes {
///     // Remove sessions after 24 hours of inactivity
///     TTLIndex(
///         named: "session-expiry",
///         field: "lastAccess",
///         expireAfterSeconds: 24 * 60 * 60
///     )
/// }
/// ```
/// 
/// - Note: The field must contain dates. The document will be removed after
///         `seconds` have elapsed since the time specified in the indexed field.
public func TTLIndex(
    named name: String,
    field: String,
    expireAfterSeconds seconds: Int
) -> _MongoIndex {
    // Ascending or descending doesn't matter on one index
    SortedIndex(named: name, field: field)
        .ttl(seconds: seconds)
}

/// Creates a text index for full-text search capabilities.
///
/// - Parameters:
///   - name: A unique name for the index
///   - field: The field to enable text search on
/// - Returns: An index specification
///
/// ## Example
/// ```swift
/// try await articles.buildIndexes {
///     // Enable text search on article content
///     TextScoreIndex(named: "content-search", field: "content")
/// }
///
/// // Later, search for articles
/// let articles = try await articles.find([
///     "$text": ["$search": "mongodb indexes"] as Document
/// ])
/// ```
/// 
/// - Note: A collection can have at most one text index.
public func TextScoreIndex(
    named name: String,
    field: String
) -> _MongoIndex {
    // Ascending or descending doesn't matter on one index
    _MongoIndex(index: CreateIndexes.Index(named: name, key: field, order: .textScore))
}
