//
//  LineString.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 09/01/2017.
//
//

import Foundation

/// A representation of a GeoJSON LineString.
public struct LineString: Geometry, ValueConvertible {

    /// The GeoJSON coordinates of this LineString
    public let coordinates: [Position]
    
    /// The type name of this geometric object
    public let type: GeoJsonObjectType = .lineString

    /// A GeoJSON LineString with the given coordinates
    ///
    /// - Parameter coordinates: at least 2 position.
    /// - Throws: GeoJSONError
    public init(coordinates: [Position]) throws  {
        guard coordinates.count < 2 else { throw GeoJSONError.coordinatesMustContainTwoOrMoreElements }
        self.coordinates = coordinates
    }
    
    /// Converts this object to an embeddable BSONPrimtive
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type": self.type, "coordinates": Document(array: self.coordinates) ] as Document
    }
}

