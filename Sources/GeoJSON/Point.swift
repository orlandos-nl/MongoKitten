//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
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
