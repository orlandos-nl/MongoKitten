//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Foundation
import BSON


/// A GeoJSon Coordinate Reference System (CRS).
public struct CoordinateReferenceSystem {
    /// The type of this Coordinate Reference System.
    public let typeName: String

    /// Creates a new CoordinateReferenceSystem object
    public init(typeName: String) {
        self.typeName = typeName
    }
}

extension CoordinateReferenceSystem: ValueConvertible {
    /// Converts the CoordinateReferenceSystem to an embeddable BSON Type
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type": "name", "properties": ["name": self.typeName] as Document] as Document
    }
}

extension CoordinateReferenceSystem: ExpressibleByStringLiteral{
    /// Allows instantiation of a CoordinateReferenceSystem with a String
    public init(stringLiteral value: String) {
        self.typeName = value
    }
    
    /// Allows instantiation of a CoordinateReferenceSystem with a String
    public init(extendedGraphemeClusterLiteral value: String) {
        self.typeName = value
    }
    
    /// Allows instantiation of a CoordinateReferenceSystem with a String
    public init(unicodeScalarLiteral value: String) {
        self.typeName = value
    }
}


extension CoordinateReferenceSystem: Hashable {
    /// Compares two CoordinateReferenceSystems
    public static func ==(lhs: CoordinateReferenceSystem, rhs: CoordinateReferenceSystem) -> Bool {
        return lhs.typeName == rhs.typeName
    }

    /// Makes a CoordinateReferenceSystem hashable
    public var hashValue: Int {
        return self.typeName.hashValue
    }
}

/// Coordinate Reference System available in MongoDB
///
/// - crs84CRS: http://portal.opengeospatial.org/files/?artifact_id=24045
/// - epsg4326CRS: http://spatialreference.org/ref/epsg/4326/
/// - strictCRS: http://www.geojson.org/geojson-spec.html#named-crs
public enum MongoCRS: CoordinateReferenceSystem {
    /// http://portal.opengeospatial.org/files/?artifact_id=24045
    case crs84CRS = "urn:ogc:def:crs:OGC:1.3:CRS84"
    
    /// http://spatialreference.org/ref/epsg/4326/
    case epsg4326CRS = "EPSG:4326"
    
    /// http://www.geojson.org/geojson-spec.html#named-crs
    case strictCRS = "urn:x-mongodb:crs:strictwinding:EPSG:4326"
}
