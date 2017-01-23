//
//  MultiLineString.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 17/01/2017.
//
//

import Foundation

/// An array of LineStrings
public struct MultiLineString: Geometry, ValueConvertible {
    /// The LineStrings
    public let coordinates: [LineString]

    /// The type name of this geometric object
    public let type: GeoJsonObjectType = .multiLineString

    /// Creates a new MultiLineString
    public init(coordinates: [LineString]) {
        self.coordinates = coordinates
    }
    
    /// Converts this object to an embeddable BSONPrimtive
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type": self.type.rawValue, "coordinates": Document(array: self.coordinates) ] as Document
    }
}
