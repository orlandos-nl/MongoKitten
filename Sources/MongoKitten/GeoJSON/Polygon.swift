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
    
    public let exterior: [Position]
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
