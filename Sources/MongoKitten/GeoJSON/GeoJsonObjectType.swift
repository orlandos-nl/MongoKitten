//
//  GeoJsonObjectType.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 07/01/2017.
//
//

import Foundation


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
struct GeometryOperator {
    /// The key to query
    let key: String
    
    /// The operator to use
    let operatorName: String
    
    /// The geometry to use in combination with the operator
    let geometry: Geometry
    
    /// Limits results to documents that are within the `maxDistance` from the center point
    let maxDistance: Double?
    
    /// Limits results to documents that are at least `minDistance` from the center point
    let minDistance: Double?

    /// Creates a new geometric operator instance
    init(key: String, operatorName: String, geometry: Geometry, maxDistance: Double? = nil, minDistance: Double? = nil) {
        self.key = key
        self.operatorName = operatorName
        self.geometry = geometry
        self.maxDistance = maxDistance
        self.minDistance = minDistance
    }

    /// Converts this object to a BSONDocument
    func makeDocument() -> Document {
        guard let geoValue = self.geometry as? ValueConvertible else { return Document() }
        var geometry = Document(dictionaryLiteral: ("$geometry", geoValue))

        geometry["$maxDistance"] = self.maxDistance
        geometry["$minDistance"]  = self.minDistance

       return [key: [operatorName:geometry] as Document ] as Document
    }
}

/// Requires the resulting data to be near the provided point
///
/// Also allows further configuration of the query
///
/// Further information and details: https://docs.mongodb.com/manual/reference/command/geoNear/
public struct GeoNearOption: ValueConvertible {
    /// The point which you're looking near
    public let near: Point
    
    /// If true, then MongoDB uses spherical geometry to calculate distances in meters if the specified (near) point is a GeoJSON point and in radians if the specified (near) point is a legacy coordinate pair.
    ///
    /// If false, then MongoDB uses 2d planar geometry to calculate distance between points.
    public let spherical: Bool
    
    /// Limits the returned results
    /// 
    /// 100 by default
    public let limit: Int?
    
    /// The minimum distance from the center point resulting Documents must be
    public let minDistance: Double?
    
    /// The maximum distance from the center point resulting Documents must be
    public let maxDistance: Double?
    
    /// Requires resulting documents to also match this query, besides the geolocation query
    public let query: Query?
    
    /// The factor to multiply all distances returned by the query. For example, use the distanceMultiplier to convert radians, as returned by a spherical query, to kilometers by multiplying by the radius of the Earth.
    public let distanceMultiplier: Double?
    
    /// Outputs each matching document once, even if multiple fields match the query
    ///
    /// Deprecated in 2.6
    public let uniqueDocs: Bool?
    
    /// This specifies the output field that identifies the location used to calculate the distance.
    public let includeLocs: String?

    /// Creates GeoNear options
    public init(near: Point, spherical: Bool, limit: Int? = nil, minDistance: Double? = nil, maxDistance: Double? = nil, query: Query? = nil, distanceMultiplier: Double? = nil, uniqueDocs: Bool? = nil, includeLocs: String? = nil) {
        self.near = near
        self.spherical = spherical
        self.limit = limit
        self.minDistance = minDistance
        self.maxDistance = maxDistance
        self.query = query
        self.distanceMultiplier = distanceMultiplier
        self.uniqueDocs = uniqueDocs
        self.includeLocs = includeLocs
    }
    
    /// Creates a Document for these options
    public func makeDocument() -> Document {
        return ["near":near,
                "spherical": spherical,
                "limit": limit,
                "minDistance": minDistance,
                "maxDistance": maxDistance,
                "query": query,
                "distanceMultiplier": distanceMultiplier,
                "uniqueDocs": uniqueDocs,
                "includeLocs": includeLocs]
    }
    
    /// Makes this an embeddable primitive
    public func makeBSONPrimitive() -> BSONPrimitive {
         return makeDocument()
    }
}
