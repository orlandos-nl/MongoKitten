/// A representation of a used - or usable - version of MongoDB's wire protocol.
/// Contains computed properties that can protocol level support for features.
public struct WireVersion: Codable, Comparable, ExpressibleByIntegerLiteral, Sendable {
    public static func < (lhs: WireVersion, rhs: WireVersion) -> Bool {
        return lhs.version < rhs.version
    }
    
    // protocol 1 and 2 are for mongoDB 2.6
    
    public static let mongo3_0: WireVersion = 3
    public static let mongo3_2: WireVersion = 4
    public static let mongo3_4: WireVersion = 5
    public static let mongo3_6: WireVersion = 6
    public static let mongo4_0: WireVersion = 7
    public static let mongo4_2: WireVersion = 8
    public static let mongo4_4: WireVersion = 9
    public static let mongo5_0: WireVersion = 13
    public static let mongo5_1: WireVersion = 14
    public static let mongo5_2: WireVersion = 15
    public static let mongo5_3: WireVersion = 16

    public let version: Int

    // Wire version 3
    public var supportsScramSha1: Bool { return version >= 3 }
    public var supportsListIndexes: Bool { return version >= 3 }
    public var supportsListCollections: Bool { return version >= 3 }
    public var supportsExplain: Bool { return version >= 3 }

    // Wire version 4
    public var supportsCursorCommands: Bool { return version >= 4 }
    public var supportsReadConcern: Bool { return version >= 4 }
    public var supportsDocumentValidation: Bool { return version >= 4 }
    //    currentOp command
    //    fsyncUnlock command
    //    findAndModify take write concern
    //    explain command supports distinct and findAndModify

    // Wire version 5
    public var supportsWriteConcern: Bool { return version >= 5 }
    public var supportsCollation: Bool { return version >= 5 }

    // Wire version 6
    public var supportsOpMessage: Bool { return version >= 6 }
    public var supportsCollectionChangeStream: Bool { return version >= 6 }
    public var supportsSessions: Bool { return version >= 6 }
    public var supportsRetryableWrites: Bool { return version >= 6 }
    // TODO: Causally Consistent Reads
    public var supportsArrayFiltersOption: Bool { return version >= 6 }

    // Wire version 7
    public var supportsDatabaseChangeStream: Bool { return version >= 7 }
    public var supportsClusterChangeStream: Bool { return version >= 7 }
    public var supportsReplicaTransactions: Bool { return version >= 7 }

    // Wire version 8
    public var supportsShardedTransactions: Bool { return version >= 8 }
    
    // Wire version 13
    public var supportsOutMergeOnSecondaries: Bool { return version >= 13 }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        self.version = try container.decode(Int.self)
    }

    public init(integerLiteral value: Int) {
        self.version = value
    }

    public func encode(to encoder: Encoder) throws {
        try version.encode(to: encoder)
    }
    
    public var isDeprecated: Bool {
        return self < .mongo4_2
    }
}
