//
//  GeoJsonObjectType.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 07/01/2017.
//
//

import Foundation

/// Defines a geo
enum GeoJsonObjectType: String {
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
