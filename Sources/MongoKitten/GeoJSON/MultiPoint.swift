//
//  MultiPoint.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 17/01/2017.
//
//

import Foundation

/// An array of positions
public struct MultiPoint: Geometry {
    /// The positions array
    public let coordinates: [Point]
    
    /// The type name of this geometric object
    public let type: GeoJsonObjectType = .multiPoint

    /// Initializes this MultiPoint gemetric object
    public init(coordinates: [Point]) {
        self.coordinates = coordinates
    }
}

extension MultiPoint: ValueConvertible {
    /// Converts this object to an embeddable BSONPrimtive
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type": self.type.rawValue, "coordinates": Document(array: self.coordinates) ] as Document
    }
}
