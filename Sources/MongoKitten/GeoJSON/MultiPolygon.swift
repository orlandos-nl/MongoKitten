//
//  MultiPolygon.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 17/01/2017.
//
//

import Foundation

public struct MultiPolygon: Geometry {
    public let coordinates: [Polygon]
    public let type: GeoJsonObjectType = .multiPolygon

    public init(coordinates: [Polygon]) {
        self.coordinates = coordinates
    }
}

extension MultiPolygon: ValueConvertible {
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type": self.type.rawValue, "coordinates": Document(array: self.coordinates) ] as Document
    }
}
