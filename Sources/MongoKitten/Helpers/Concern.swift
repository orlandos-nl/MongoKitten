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
    case custom(w: BSON.Primitive, j: Bool?, wTimeout: Int)
    
    /// Converts this WriteConcern to a BSON.Primitive for embedding
    public func makePrimitive() -> BSON.Primitive {
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
    
    /// Converts this object to a BSON.Primitive
    public func makePrimitive() -> BSON.Primitive {
        return [
            "level": self.rawValue
        ] as Document
    }
}

/// https://docs.mongodb.com/manual/reference/collation/#collation-document-fields
public struct Collation: ValueConvertible {
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
    
    /// Converts this Collation to a BSONPrimtive so it can be embedded
    public func makePrimitive() -> BSON.Primitive {
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
    public enum IgnorableCharacters: String, ValueConvertible {
        /// Both whitespaces and punctuation are “ignorable”, i.e. not considered base characters.
        case punct = "punct"
        
        /// Whitespace are “ignorable”, i.e. not considered base characters.
        case space = "space"
        
        /// Converts this object to a BSON.Primitive
        public func makePrimitive() -> BSON.Primitive {
            return self.rawValue
        }
    }
    
    /// Determines whether collation should consider whitespace and punctuation as base characters for purposes of comparison.
    public enum Alternate: String, ValueConvertible {
        /// Whitespace and punctuation are considered base characters.
        case nonIgnorable = "non-ignorable"
        
        /// Whitespace and punctuation are not considered base characters and are only distinguished at strength levels greater than 3.
        case shifted
        
        /// Converts this to a BSON.Primitive
        public func makePrimitive() -> BSON.Primitive {
            return self.rawValue
        }
    }
    
    /// The ICU comparison level: http://userguide.icu-project.org/collation/concepts#TOC-Comparison-Levels
    public enum Strength: Int32, ValueConvertible {
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
        
        /// Converts this Strength to a BSON.Primitive
        public func makePrimitive() -> BSON.Primitive {
            return self.rawValue
        }
    }
}
