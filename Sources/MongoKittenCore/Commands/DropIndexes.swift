import BSON
import MongoCore

public struct DropIndexes: Encodable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case dropIndexes
        case index
        case writeConcern
    }

    /// Collection name
    private let dropIndexes: String

    /// Index name, list of names, or "*"
    public let index: IndexSpecifier

    /// Optional write concern
    public var writeConcern: WriteConcern?

    public init(collection: String, index: IndexSpecifier) {
        self.dropIndexes = collection
        self.index = index
    }
}

// MARK: - Index Specifier

public enum IndexSpecifier: Encodable, Sendable {
    case name(String)
    case names([String])
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
