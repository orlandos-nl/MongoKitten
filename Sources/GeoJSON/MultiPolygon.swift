//
//  MultiPolygon.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 17/01/2017.
//
//

import Foundation
import BSON

/// An group of polygons
public struct MultiPolygon: Geometry {
    /// The polygons array
    public let coordinates: [Polygon]
    
    /// The type name of this geometric object
    public let type: GeoJsonObjectType = .multiPolygon

    /// Creates a new MultiPolygon object
    public init(coordinates: [Polygon]) {
        self.coordinates = coordinates
    }
}

extension MultiPolygon: ValueConvertible {
    /// Converts this object to an embeddable BSONPrimtive
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type": self.type.rawValue, "coordinates": Document(array: self.coordinates) ] as Document
    }
}
