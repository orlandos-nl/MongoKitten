//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import BSON

/// A WriteConcern describes the requested level of acknowledgement for a Write operation such as `delete`, `update` or `insert`.
public enum WriteConcern: ValueConvertible {
    /// Best described here: https://docs.mongodb.com/manual/reference/write-concern/
    ///
    /// w: When set to `1` it'll request acknowledgement, `0` will request no acknowledgement for the Write operation
    /// When set to "majority" this will request acknowledgement of the majority of nodes within a cluster or replica set
    ///
    /// j: Acknowledgement for the completion of writing this information to the journal
    ///
    /// wTimeout: The time in milliseconds that's being waited for the acknowledgement. An error will be thrown otherwise.
    case custom(w: ValueConvertible, j: Bool?, wTimeout: Int)
    
    /// Converts this WriteConcern to a BSONPrimitive for embedding
    public func makeBSONPrimitive() -> BSONPrimitive {
        switch self {
        case .custom(let w, let j, let timeout):
            return [
                "w": w,
                "j": j,
                "wtimeout": timeout
                ] as Document
        }
    }
}

/// Used for sharded clusers and replica sets.
///
/// Determines which data to return from a query
///
/// https://docs.mongodb.com/manual/reference/read-concern/#readconcern.
public enum ReadConcern: String, ValueConvertible {
    /// The query returns the instance’s most recent data. Provides no guarantee that the data has been written to a majority of the replica set members
    case local
    
    /// The query returns the instance’s most recent data acknowledged as having been written to a majority of members in the replica set.
    case majority
    
    /// The query returns data that reflects all successful writes issued with a write concern of "majority" and acknowledged prior to the start of the read operation.
    case linearizable
    
    /// Converts this object to a BSONPrimitive
    public func makeBSONPrimitive() -> BSONPrimitive {
        return [
            "level": self.rawValue
        ] as Document
    }
}

/// https://docs.mongodb.com/manual/reference/collation/#collation-document-fields
public struct Collation: CustomValueConvertible {
    /// The ICU locale
    /// "simple" for binary comparison
    let locale: String
    
    /// Flag that determines whether to include case comparison at strength level 1 (.primary) or 2 (.secondary)
    let caseLevel: Bool
    
    // TODO: let caseFirst: Bool
    
    /// The ICU comparison level: http://userguide.icu-project.org/collation/concepts#TOC-Comparison-Levels
    let strength: Strength
    
    /// Determines whether to compare numeric strings as numbers or as strings.
    let numericOrdering: Bool
    
    /// Determines whether collation should consider whitespace and punctuation as base characters for purposes of comparison.
    let alternate: Alternate
    
    /// Determines up to which characters are considered ignorable when alternate: "shifted".
    let maxVariable: IgnorableCharacters?
    
    /// Determines whether strings with diacritics sort from back of the string, such as with some French dictionary ordering.
    let backwards: Bool
    
    /// Determines whether to check if text require normalization and to perform normalization.
    let normalization: Bool
    
    /// Creates an instance of Alternate from a Collation, if possible
    public init?(_ value: BSONPrimitive) {
        guard let doc = value.documentValue else {
            return nil
        }
        
        guard let caseLevel = doc["caseLevel"] as Bool? else {
            return nil
        }
        
        self.locale = doc["locale"] as String? ?? "simple"
        self.strength = (doc.extract("strength") as Strength?) ?? .tertiary
        self.caseLevel = caseLevel
        self.numericOrdering = doc["numericOrdering"] as Bool? ?? false
        self.alternate = (doc.extract("alternate") as Alternate?) ?? .nonIgnorable
        self.normalization = (doc["normalization"] as Bool?) ?? false
        self.backwards = (doc["backwards"] as Bool?) ?? false
        self.maxVariable = doc.extract("maxVariable") as IgnorableCharacters?
    }
    
    /// Converts this Collation to a BSONPrimtive so it can be embedded
    public func makeBSONPrimitive() -> BSONPrimitive {
        return [
            "locale": locale,
            "caseLevel": caseLevel,
            "strength": strength,
            "numericOrdering": numericOrdering,
            "alternate": alternate,
            "normalization": normalization,
            "backwards": backwards,
            "maxVariable": maxVariable
        ] as Document
    }
    
    /// Determines up to which characters are considered ignorable when alternate: "shifted".
    public enum IgnorableCharacters: String, CustomValueConvertible {
        /// Both whitespaces and punctuation are “ignorable”, i.e. not considered base characters.
        case punct = "punct"
        
        /// Whitespace are “ignorable”, i.e. not considered base characters.
        case space = "space"
        
        /// Creates an instance of IgnorableCharacters from a BSONPrimitive, if possible
        public init?(_ value: BSONPrimitive) {
            guard let string = value.string else {
                return nil
            }
            
            switch string {
            case "punct":
                self = .punct
            case "space":
                self = .space
            default:
                return nil
            }
        }
        
        /// Converts this object to a BSONPrimitive
        public func makeBSONPrimitive() -> BSONPrimitive {
            return self.rawValue
        }
    }
    
    /// Determines whether collation should consider whitespace and punctuation as base characters for purposes of comparison.
    public enum Alternate: String, CustomValueConvertible {
        /// Whitespace and punctuation are considered base characters.
        case nonIgnorable = "non-ignorable"
        
        /// Whitespace and punctuation are not considered base characters and are only distinguished at strength levels greater than 3.
        case shifted
        
        /// Creates an instance of Alternate from a BSONPrimitive, if possible
        public init?(_ value: BSONPrimitive) {
            guard let string = value.string else {
                return nil
            }
            
            switch string {
            case "non-ignorable":
                self = .nonIgnorable
            case "shifted":
                self = .shifted
            default:
                return nil
            }
        }
        
        /// Converts this to a BSONPrimitive
        public func makeBSONPrimitive() -> BSONPrimitive {
            return self.rawValue
        }
    }
    
    /// The ICU comparison level: http://userguide.icu-project.org/collation/concepts#TOC-Comparison-Levels
    public enum Strength: Int32, CustomValueConvertible {
        /// 1: Performs comparisons of the base characters only, ignoring other differences such as diacritics and case
        case primary = 1
        
        /// 2: Performs comparisons up to secondary differences, such as diacritics.
        case secondary = 2
        
        /// 3 (default): Performs comparisons up to tertiary differences, such as case and letter variants.
        case tertiary = 3
        
        /// 4: Same as 3, but requires proper punctuation or for comparing japanese text
        case quaternary = 4
        
        /// 5: Identical texts
        case identical = 5
        
        /// Creates a Strength instance from a BSONPrimitive
        public init?(_ value: BSONPrimitive) {
            guard let number = value.int32 else {
                return nil
            }
            
            switch number {
            case 1:
                self = .primary
            case 2:
                self = .secondary
            case 3:
                self = .tertiary
            case 4:
                self = .quaternary
            case 5:
                self = .identical
            default:
                return nil
            }
        }
        
        /// Converts this Strength to a BSONPrimitive
        public func makeBSONPrimitive() -> BSONPrimitive {
            return self.rawValue
        }
    }
}
