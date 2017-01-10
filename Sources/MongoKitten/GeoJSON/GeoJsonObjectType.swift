//
//  GeoJsonObjectType.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 07/01/2017.
//
//

import Foundation

enum GeoJsonObjectType: String {
    case point = "Point"
    case multiPoint = "MultiPoint"
    case lineString = "LineString"
    case multiLineString = "MultiLineString"
    case polygon = "Polygon"
    case multiPolygon = "MultiPolygon"
    case geometryCollection = "GeometryCollection"
}
