//
//  MultiLineString.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 17/01/2017.
//
//

import Foundation

struct MultiLineString: Geometry {
    public let coordinates: [LineString]

    public let type: GeoJsonObjectType = .multiLineString

    public init(coordinates: [LineString]) {
        self.coordinates = coordinates
    }
}

extension MultiLineString: ValueConvertible {
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type": self.type.rawValue, "coordinates": Document(array: self.coordinates) ] as Document
    }
}
