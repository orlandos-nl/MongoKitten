import BSON
import MongoCore

/// Represents a MongoDB dropIndexes command for a specific collection.
///
/// This struct is used to encode the necessary information to drop one or more indexes
/// from a collection. It supports dropping by a single index name, multiple names, or all indexes.
///
/// Example usage:
/// ```swift
/// let drop = DropIndexes(collection: "users", index: .name("email_1"))
/// ```
public struct DropIndexes: Encodable, Sendable {
    /// The name of the collection from which indexes should be dropped.
    private let dropIndexes: String

    /// Specifies which indexes to drop. Can be a single index, multiple indexes, or all indexes.
    public let index: IndexSpecifier

    /// Optional write concern to control the acknowledgment of the drop operation.
    public var writeConcern: WriteConcern?

    /// Creates a new `DropIndexes` command.
    /// - Parameters:
    ///   - collection: The name of the collection.
    ///   - index: The indexes to drop (`IndexSpecifier`).
    public init(collection: String, index: IndexSpecifier) {
        self.dropIndexes = collection
        self.index = index
    }
}

// MARK: - IndexSpecifier

/// Specifies which MongoDB indexes should be targeted in an operation.
///
/// `IndexSpecifier` provides a flexible way to reference indexes by:
/// - a single name
/// - multiple names
/// - or all indexes in a collection
///
/// It also supports convenient literal initialization via string and array literals.
public enum IndexSpecifier: Encodable, Sendable {
    /// A single index name.
    ///
    /// Example:
    /// ```swift
    /// .name("username_1")
    /// ```
    case name(String)
    /// Multiple index names.
    ///
    /// Example:
    /// ```swift
    /// .names(["username_1", "email_1"])
    /// ```
    ///
    /// - Complexity: O(n), where `n` is the number of index names.
    case names([String])
    /// All indexes in the collection.
    ///
    /// This is typically encoded as `"*"`.
    case all
}

extension IndexSpecifier: ExpressibleByStringLiteral {
    /// Creates an `IndexSpecifier` from a string literal.
    ///
    /// - If the value is `"*"`, it maps to `.all`
    /// - Otherwise, it maps to `.name(value)`
    ///
    /// Example:
    /// ```swift
    /// let spec: IndexSpecifier = "username_1" // .name("username_1")
    /// let all: IndexSpecifier = "*"           // .all
    /// ```
    public init(stringLiteral value: String) {
        if value == "*" {
            self = .all
        } else {
            self = .name(value)
        }
    }
}

extension IndexSpecifier: ExpressibleByArrayLiteral {
    /// The element type for array literal initialization.
    public typealias ArrayLiteralElement = String
    /// Creates an `IndexSpecifier` from an array literal of index names.
    ///
    /// Example:
    /// ```swift
    /// let spec: IndexSpecifier = ["username_1", "email_1"]
    /// // Equivalent to .names(["username_1", "email_1"])
    /// ```
    ///
    /// - Complexity: O(n), where `n` is the number of elements.
    public init(arrayLiteral elements: String...) {
        self = .names(elements)
    }
}

extension IndexSpecifier {
    /// Encodes the `IndexSpecifier` into the appropriate format for MongoDB.
    ///
    /// - `.name(String)` encodes as a single string (the index name).
    /// - `.names([String])` encodes as an array of strings (multiple index names).
    /// - `.all` encodes as `"*"` to indicate all indexes.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .name(let name):
            try container.encode(name)
        case .names(let names):
            try container.encode(names)
        case .all:
            try container.encode("*")
        }
    }
}
