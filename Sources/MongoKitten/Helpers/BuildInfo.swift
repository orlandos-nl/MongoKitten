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

/// A semantic version
public struct Version: Codable, Comparable {
    /// Major level
    public let major: Int
    
    /// Minor level
    public let minor: Int
    
    /// Patch level
    public let patch: Int
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.string)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        guard let me = Version(try container.decode(String.self)) else {
            throw MongoError.invalidBuildInfoDocument
        }
        
        self = me
    }

    /// Initializes using the major, minor, patch
    public init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    /// Converts to this from a String
    public init?(_ value: String) {
        let numbers = value.components(separatedBy: ".").flatMap {
            Int($0)
        }
        
        guard numbers.count == 3 else {
            return nil
        }
        
        self.major = numbers[0]
        self.minor = numbers[1]
        self.patch = numbers[2]
    }
    
    /// Creates an embeddable BSON.Primitive (String)
    public var string: String {
        return "\(major).\(minor).\(patch)"
    }
    
    /// Equates two versions
    public static func ==(lhs: Version, rhs: Version) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
    
    /// Checks if the left version is newer than the right version
    public static func >(lhs: Version, rhs: Version) -> Bool {
        if lhs.major > rhs.major {
            return true
        } else if lhs.major == rhs.major {
            if lhs.minor > rhs.minor {
                return true
            } else if lhs.minor == rhs.minor {
                return lhs.patch > rhs.patch
            }
        }
        
        return false
    }
    
    /// Checks if the left version is older than the right version
    public static func <(lhs: Version, rhs: Version) -> Bool {
        if lhs.major < rhs.major {
            return true
        } else if lhs.major == rhs.major {
            if lhs.minor < rhs.minor {
                return true
            } else if lhs.minor == rhs.minor {
                return lhs.patch < rhs.patch
            }
        }
        
        return false
    }
    
    /// Checks if the left version is newer or equal to the right version
    public static func >=(lhs: Version, rhs: Version) -> Bool {
        if lhs.major < rhs.major {
            return false
        } else if lhs.major == rhs.major {
            if lhs.minor < rhs.minor {
                return false
            } else if lhs.minor == rhs.minor {
                return lhs.patch >= rhs.patch
            }
        }
        
        return true
    }
    
    /// Checks if the left version is older or equal to right version
    public static func <=(lhs: Version, rhs: Version) -> Bool {
        if lhs.major > rhs.major {
            return false
        } else if lhs.major == rhs.major {
            if lhs.minor > rhs.minor {
                return false
            } else if lhs.minor == rhs.minor {
                return lhs.patch <= rhs.patch
            }
        }
        
        return true
    }
}

/// MongoDB build information
public struct BuildInfo: Codable {
    /// The git version
    public let gitVersion: String
    
    /// An array of version information
    public let versionArray: Document
    
    /// The semantic version of this build
    public let version: Version
    
    /// The available storage engines in 3.2 or above
    public let storageEngines: Document?
    
    /// The processor architecture
    public let bits: Int
    
    /// Build as debug server
    public let debug: Bool
    
    /// Maximum BSON object size (usually 16MB)
    public let maxBsonObjectSize: Int
    
    /// OpenSSL details, if available
    public let openSSL: Document?
    
    /// The add-on modules on the server
    public let modules: Document
}
