//
//  Point.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 07/01/2017.
//
//

import Foundation
import BSON

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
    /// Converts this object to an embeddable BSONPrimtive
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type": self.type.rawValue, "coordinates": self.coordinate ] as Document
    }
}

extension Point: Hashable {
    /// Compares two points to be equal to each other
    public static func == (lhs: Point, rhs: Point) -> Bool {
        return lhs.coordinate == rhs.coordinate
    }

    /// Makes a point hashable, thus usable as a key in a dictionary
    public var hashValue: Int {
        return self.coordinate.hashValue
    }
}
