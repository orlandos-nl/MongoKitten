//
//  Polygon.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 09/01/2017.
//
//

import Foundation


/// Coordinates for a GeoJSON Polygon.
public struct PolygonCoordinates {

    /// The exterior ring of the polygon
    public let exterior: [Position]
    
    /// The interior rings of the polygon
    public let holes: [[Position]]

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
    public func makeBSONPrimitive() -> BSONPrimitive {
        var docs = Document()
        docs.append(Document(array: exterior))
        for coords in holes {
            docs.append(Document(array: coords))
        }

        return docs
    }
}


extension PolygonCoordinates: Hashable {

    public static func == (lhs: PolygonCoordinates, rhs: PolygonCoordinates) -> Bool {

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

    public let coordinates: PolygonCoordinates

    public let type: GeoJsonObjectType = .polygon

    public init(exterior:[Position], holes:[Position]...) throws {
        self.coordinates = try PolygonCoordinates(exterior: exterior, holes: holes)
    }

}

extension Polygon: ValueConvertible {
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type":self.type.rawValue, "coordinates":self.coordinates] as Document
    }
}


extension Polygon: Hashable {
    public static func == (lhs: Polygon, rhs: Polygon) -> Bool {
        return lhs.coordinates == rhs.coordinates
    }


    public var hashValue: Int {
        return self.coordinates.hashValue
    }
}
