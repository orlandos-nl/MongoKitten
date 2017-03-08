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
public struct Version: ValueConvertible, Comparable {
    /// -
    public let major: Int
    
    /// -
    public let minor: Int
    
    /// -
    public let patch: Int

    /// Initializes using the major, minor, patch
    public init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    /// Converts to this from a String
    public init?(_ value: BSON.Primitive?) {
        guard let value = String(value) else {
            return nil
        }
        
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
    public func makePrimitive() -> BSON.Primitive {
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
public struct BuildInfo: ValueConvertible {
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
    
    /// Creates this from a Document, but throwable
    public init(fromDocument document: Document) throws {
        guard let gitVersion = String(document["gitVersion"]) else {
            throw MongoError.invalidBuildInfoDocument
        }
        
        guard let versionArray = Document(document["versionArray"]) else {
            throw MongoError.invalidBuildInfoDocument
        }
        
        guard let version = Version(document["version"]) else {
            throw MongoError.invalidBuildInfoDocument
        }
        
        let storageEngines = Document(document["storageEngines"])
        
        guard let bits = Int(document["bits"]) else {
            throw MongoError.invalidBuildInfoDocument
        }
        
        guard let debug = Bool(document["debug"]) else {
            throw MongoError.invalidBuildInfoDocument
        }
        
        guard let maxBsonObjectSize = Int(document["maxBsonObjectSize"]) else {
            throw MongoError.invalidBuildInfoDocument
        }
        
        let openSSL = Document(document["openssl"])
        
        let modules = Document(document["modules"]) ?? []
        
        self.gitVersion = gitVersion
        self.versionArray = versionArray
        self.version = version
        self.storageEngines = storageEngines
        self.bits = bits
        self.debug = debug
        self.maxBsonObjectSize = maxBsonObjectSize
        self.openSSL = openSSL
        self.modules = modules
    }
    
    /// Converts this back to a Document
    public func makePrimitive() -> BSON.Primitive {
        return [
            "gitVersion": gitVersion,
            "versionArray": versionArray,
            "version": version,
            "storageEngines": storageEngines,
            "bits": bits,
            "debug": debug,
            "maxBsonObjectSize": maxBsonObjectSize,
            "openssl": openSSL,
            "modules": modules
        ] as Document
    }
}
