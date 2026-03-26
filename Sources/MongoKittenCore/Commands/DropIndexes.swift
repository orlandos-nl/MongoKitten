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

extension DropIndexes {
    private enum CodingKeys: String, CodingKey {
        case dropIndexes
        case index
        case writeConcern
    }
}

// MARK: - Index Specifier

/// Describes which index or indexes should be dropped in a `DropIndexes` command.
///
/// Can be a single index, multiple indexes, or all indexes in the collection.
public enum IndexSpecifier: Encodable, Sendable {
    /// Drop a single index by name.
    case name(String)

    /// Drop multiple indexes by names.
    case names([String])

    /// Drop all indexes in the collection.
    case all

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
