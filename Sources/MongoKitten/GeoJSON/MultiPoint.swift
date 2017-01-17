//
//  MultiPoint.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 17/01/2017.
//
//

import Foundation

public struct MultiPoint: Geometry {
    public let coordinates: [Point]
    public let type: GeoJsonObjectType = .multiPoint

    public init(coordinates: [Point]) {
        self.coordinates = coordinates
    }
}

extension MultiPoint: ValueConvertible {
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type": self.type.rawValue, "coordinates": Document(array: self.coordinates) ] as Document
    }
}
