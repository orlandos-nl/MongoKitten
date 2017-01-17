//
//  GeoJsonObjectType.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 07/01/2017.
//
//

import Foundation


/// Defines a geo
public enum GeoJsonObjectType: String {
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
}

public protocol Geometry {
    var type: GeoJsonObjectType { get }
    
}


struct GeometryOperator {
    let key: String
    let operatorName: String
    let geometry: Geometry
    let maxDistance: Double?
    let minDistance: Double?

    init(key: String, operatorName: String, geometry: Geometry, maxDistance: Double? = nil, minDistance: Double? = nil) {
        self.key = key
        self.operatorName = operatorName
        self.geometry = geometry
        self.maxDistance = maxDistance
        self.minDistance = minDistance
    }

    func document() -> Document {

        guard let geoValue = self.geometry as? ValueConvertible else { return Document() }
        var geometry = Document(dictionaryLiteral: ("$geometry", geoValue))

        if let maxDistance = self.maxDistance {
            geometry["$maxDistance"] = maxDistance
        }

        if let minDistance = self.minDistance {
            geometry["$minDistance"]  = minDistance
        }

       return [key: [operatorName:geometry] as Document ] as Document
    }
}

public struct GeoNearOption {

    public let near: Point
    public let distanceField: String
    public let spherical: Bool
    public let limit: Int?
    public let num: Int?
    public let minDistance: Double?
    public let maxDistance: Double?
    public let query: Document?
    public let distanceMultiplier: Double?
    public let uniqueDocs: Bool?
    public let includeLocs: String?

    public init(near: Point, spherical: Bool, distanceField: String, limit: Int? = nil, num: Int? = nil, minDistance: Double? = nil, maxDistance: Double? = nil, query: Document? = nil, distanceMultiplier: Double? = nil, uniqueDocs: Bool? = nil, includeLocs: String? = nil) {
        self.near = near
        self.spherical = spherical
        self.distanceField = distanceField
        self.limit = limit
        self.num = num
        self.minDistance = minDistance
        self.maxDistance = maxDistance
        self.query = query
        self.distanceMultiplier = distanceMultiplier
        self.uniqueDocs = uniqueDocs
        self.includeLocs = includeLocs
    }
}

extension GeoNearOption: ValueConvertible {
    public func makeBSONPrimitive() -> BSONPrimitive {
        return  ["near":near,
                                 "spherical": spherical,
                                 "distanceField": distanceField,
                                 "limit": limit,
                                 "num": num,
                                 "minDistance": minDistance,
                                 "maxDistance": maxDistance,
                                 "query": query,
                                 "distanceMultiplier": distanceMultiplier,
                                 "uniqueDocs": uniqueDocs,
                                 "includeLocs": includeLocs] as Document



    }
}
