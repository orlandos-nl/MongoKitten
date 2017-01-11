//
//  GeoJsonObjectType.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 07/01/2017.
//
//

import Foundation


public protocol Geometry {
    var type: GeoJsonObjectType { get }
}


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

struct GeometryOperator {
    let key: String
    let operatorName: String
    let geometry: ValueConvertible
    let maxDistance: Double?
    let minDistance: Double?

    init(key: String, operatorName: String, geometry: ValueConvertible, maxDistance: Double? = nil, minDistance: Double? = nil) {
        self.key = key
        self.operatorName = operatorName
        self.geometry = geometry
        self.maxDistance = maxDistance
        self.minDistance = minDistance
    }

    func document() -> Document {
        var geometry = Document(dictionaryLiteral: ("$geometry",self.geometry))

        if let maxDistance = self.maxDistance {
            geometry["$maxDistance"] = maxDistance
        }

        if let minDistance = self.minDistance {
            geometry["$minDistance"]  = minDistance
        }

       return [key: [operatorName:geometry] as Document ] as Document
    }
}
