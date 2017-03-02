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


/// Defines a geomeric shape type
public enum GeoJsonObjectType: String, ValueConvertible {
    /// A single point
    case point = "Point"
    
    /// Multiple points
    case multiPoint = "MultiPoint"
    
    /// A line from point to point
    case lineString = "LineString"
    
    /// Multiple lines
    case multiLineString = "MultiLineString"
    
    /// A single polygon
    case polygon = "Polygon"
    
    /// Multiple polygons
    case multiPolygon = "MultiPolygon"
    
    /// A collection of geometrical objects
    case geometryCollection = "GeometryCollection"
    
    /// Converts the enum case to an embeddable BSON Primtive type
    public func makeBSONPrimitive() -> BSONPrimitive {
        return self.rawValue
    }
}

/// A geometric shape
public protocol Geometry {
    /// The type name of this geometric object
    var type: GeoJsonObjectType { get }
}

/// An operator used for querying geometric shapes
public struct GeometryOperator {
    /// The key to query
    public let key: String
    
    /// The operator to use
    public let operatorName: String
    
    /// The geometry to use in combination with the operator
    public let geometry: Geometry
    
    /// Limits results to documents that are within the `maxDistance` from the center point
    public let maxDistance: Double?
    
    /// Limits results to documents that are at least `minDistance` from the center point
    public let minDistance: Double?

    /// Creates a new geometric operator instance
    public init(key: String, operatorName: String, geometry: Geometry, maxDistance: Double? = nil, minDistance: Double? = nil) {
        self.key = key
        self.operatorName = operatorName
        self.geometry = geometry
        self.maxDistance = maxDistance
        self.minDistance = minDistance
    }

    /// Converts this object to a BSONDocument
    public func makeDocument() -> Document {
        guard let geoValue = self.geometry as? ValueConvertible else { return Document() }
        var geometry = Document(dictionaryLiteral: ("$geometry", geoValue))

        geometry["$maxDistance"] = self.maxDistance
        geometry["$minDistance"]  = self.minDistance

       return [key: [operatorName:geometry] as Document ] as Document
    }
}
