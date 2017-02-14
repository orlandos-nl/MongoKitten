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

/// Coordinates for a GeoJSON Polygon.
public struct PolygonCoordinates {

    /// The exterior ring of the polygon
    public let exterior: [Position]
    
    /// The interior rings of the polygon
    public let holes: [[Position]]

    /// Creates a polygon from it's exterior and holes
    public init(exterior: [Position], holes:[[Position]]) throws {

        guard exterior.count >= 4 else { throw GeoJSONError.ringMustContainFourOrMoreElements }
        guard exterior.first == exterior.last else { throw GeoJSONError.firstAndLastPositionMustBeTheSame }

        for hole in holes {
            guard hole.count >= 4 else  { throw GeoJSONError.ringMustContainFourOrMoreElements }
            guard hole.first == hole.last else { throw GeoJSONError.firstAndLastPositionMustBeTheSame }
        }

        self.exterior = exterior
        self.holes = holes

    }
}


extension PolygonCoordinates: ValueConvertible {
    /// Converts this object to an embeddable BSONPrimtive
    public func makeBSONPrimitive() -> BSONPrimitive {
        var docs: Document = []
        docs.append(Document(array: exterior))
        for coords in holes {
            docs.append(Document(array: coords))
        }

        return docs
    }
}


extension PolygonCoordinates: Hashable {
    /// Compares to coordinate sets to be equal
    public static func ==(lhs: PolygonCoordinates, rhs: PolygonCoordinates) -> Bool {

        if lhs.holes.count != rhs.holes.count {
            return false
        } else {
            for i in 0..<lhs.holes.count {
                if lhs.holes[i] != rhs.holes[i] {
                    return false
                }
            }
        }

        return lhs.exterior == rhs.exterior
    }

    /// Makes the polygon coordinates hashable
    public var hashValue: Int {
        var hashVal = 5381

        for hole in self.holes {
            hashVal = hole.reduce(hashVal){
                ($0 << 5) &+ $0 &+ $1.hashValue
            }
        }

       hashVal = self.exterior.reduce(hashVal) {
            ($0 << 5) &+ $0 &+ $1.hashValue
        }

        return hashVal
    }
}



/// A representation of a GeoJSON Polygon.
public struct Polygon: Geometry {
    /// The coordinates
    public let coordinates: PolygonCoordinates

    /// The type name of this geometric object
    public let type: GeoJsonObjectType = .polygon

    /// Creates a new polygon
    public init(exterior:[Position], holes:[Position]...) throws {
        self.coordinates = try PolygonCoordinates(exterior: exterior, holes: holes)
    }

}

extension Polygon: ValueConvertible {
    /// Converts this object to an embeddable BSONPrimtive
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type":self.type.rawValue, "coordinates":self.coordinates] as Document
    }
}


extension Polygon: Hashable {
    /// Compares to polygons to be equal
    public static func ==(lhs: Polygon, rhs: Polygon) -> Bool {
        return lhs.coordinates == rhs.coordinates
    }

    /// Makes the polygon hashable
    public var hashValue: Int {
        return self.coordinates.hashValue
    }
}
