import BSON
import MongoCore

public struct CollMod: Encodable, Sendable {
    /// Collection name
    private let collMod: String

    /// Index modification
    public var index: Index?

    /// Optional: run without applying changes (for unique conversion)
    public var dryRun: Bool?

    /// Optional write concern
    public var writeConcern: WriteConcern?

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
    struct Index: Encodable, Sendable {
        private enum CodingKeys: String, CodingKey {
            case name
            case keyPattern
            case expireAfterSeconds
            case hidden
            case unique
            case prepareUnique
        }

        /// Use either name OR keyPattern
        public var name: String?
        public var keyPattern: Document?

        /// TTL update
        public var expireAfterSeconds: Int?

        /// Hide index from query planner
        public var hidden: Bool?

        /// Convert to unique (Mongo 6.0+)
        public var unique: Bool?

        /// Prepare unique conversion
        public var prepareUnique: Bool?

        // MARK: - Init by name
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
