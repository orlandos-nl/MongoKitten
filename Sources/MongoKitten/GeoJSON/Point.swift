//
//  Point.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 07/01/2017.
//
//

import Foundation

/// A representation of a GeoJSON Point.
public struct Point: Geometry {

    /// The GeoJSON coordinates of this point.
    public let coordinate: Position
    
    /// The type of object
    public let type: GeoJsonObjectType = .point

    /// Creates a point with the given coordinate
    public init(coordinate: Position) {
        self.coordinate = coordinate
    }

}

extension Point: ValueConvertible {
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type": self.type.rawValue, "coordinates": self.coordinate ] as Document
    }
}
