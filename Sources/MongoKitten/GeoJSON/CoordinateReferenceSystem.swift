//
//  CoordinateReferenceSystem.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 13/01/2017.
//
//

import Foundation



/// A GeoJSon Coordinate Reference System (CRS).
public struct CoordinateReferenceSystem {


    /// The type of this Coordinate Reference System.
    public let typeName: String

    public init(typeName: String) {
        self.typeName = typeName
    }
}


extension CoordinateReferenceSystem: ValueConvertible {
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type": "name", "properties": ["name": self.typeName] as Document] as Document
    }
}


extension CoordinateReferenceSystem: ExpressibleByStringLiteral{
    public init(stringLiteral value: String) {
        self.typeName = value
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self.typeName = value
    }

    public init(unicodeScalarLiteral value: String) {
        self.typeName = value
    }
}


extension CoordinateReferenceSystem: Hashable {
    public static func == (lhs: CoordinateReferenceSystem, rhs: CoordinateReferenceSystem) -> Bool {
        return lhs.typeName == rhs.typeName
    }

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
    case crs84CRS = "urn:ogc:def:crs:OGC:1.3:CRS84"
    case epsg4326CRS = "EPSG:4326"
    case strictCRS = "urn:x-mongodb:crs:strictwinding:EPSG:4326"
}
