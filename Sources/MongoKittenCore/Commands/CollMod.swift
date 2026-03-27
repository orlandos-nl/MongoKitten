import BSON
import MongoCore

/// A command to modify the configuration of an existing collection or its indexes.
///
/// This corresponds to the MongoDB `collMod` administrative command.
public struct CollMod: Encodable, Sendable {
    /// The name of the collection to modify.
    private let collMod: String

    /// Metadata for modifying an existing index.
    public var index: Index?

    /// If true, checks the index for unique constraint violations without applying the change.
    ///
    /// Useful when converting an existing index to a unique index (MongoDB 6.0+).
    public var dryRun: Bool?

    /// The level of acknowledgment requested from MongoDB for write operations.
    public var writeConcern: WriteConcern?

    /// Creates a new `collMod` command.
    /// - Parameters:
    ///   - collection: The name of the collection.
    ///   - index: Optional index modification parameters.
    ///   - dryRun: Optional flag to test unique index conversion.
    public init(
        collection: String,
        index: Index? = nil,
        dryRun: Bool? = nil
    ) {
        self.collMod = collection
        self.index = index
        self.dryRun = dryRun
    }
}

// MARK: - Index
public extension CollMod {
    /// Configuration details for modifying an index's properties.
    struct Index: Encodable, Sendable {
        private enum CodingKeys: String, CodingKey {
            case name
            case keyPattern
            case expireAfterSeconds
            case hidden
            case unique
            case prepareUnique
        }
        /// The name of the index to be modified.
        public var name: String?

        /// The key pattern of the index to be modified.
        public var keyPattern: Document?

        /// The time, in seconds, for the TTL (Time To Live) index to expire documents.
        public var expireAfterSeconds: Int?

        /// Whether to hide the index from the query planner.
        ///
        /// A hidden index is maintained but not used by the query optimizer.
        public var hidden: Bool?

        /// Whether the index should be converted to a unique index.
        ///
        /// Available in MongoDB 6.0 and later.
        public var unique: Bool?

        /// Prepares the index for a unique constraint conversion.
        ///
        /// Part of the two-step process for building unique indexes in sharded clusters.
        public var prepareUnique: Bool?

        // MARK: - Init by name

        /// Creates an index modification target identified by the index name.
        /// - Parameters:
        ///   - name: The name of the index (e.g., "_id_").
        ///   - expireAfterSeconds: New TTL value.
        ///   - hidden: New visibility status.
        ///   - unique: Whether to convert to a unique index.
        ///   - prepareUnique: Whether to prepare for unique conversion.
        public init(
            name: String,
            expireAfterSeconds: Int? = nil,
            hidden: Bool? = nil,
            unique: Bool? = nil,
            prepareUnique: Bool? = nil
        ) {
            self.name = name
            self.expireAfterSeconds = expireAfterSeconds
            self.hidden = hidden
            self.unique = unique
            self.prepareUnique = prepareUnique
        }

        // MARK: - Init by keyPattern

        /// Creates an index modification target identified by the index key pattern.
        /// - Parameters:
        ///   - keyPattern: The document defining the index keys (e.g., `["email": 1]`).
        ///   - expireAfterSeconds: New TTL value.
        ///   - hidden: New visibility status.
        ///   - unique: Whether to convert to a unique index.
        ///   - prepareUnique: Whether to prepare for unique conversion.
        public init(
            keyPattern: Document,
            expireAfterSeconds: Int? = nil,
            hidden: Bool? = nil,
            unique: Bool? = nil,
            prepareUnique: Bool? = nil
        ) {
            self.keyPattern = keyPattern
            self.expireAfterSeconds = expireAfterSeconds
            self.hidden = hidden
            self.unique = unique
            self.prepareUnique = prepareUnique
        }
    }
}

