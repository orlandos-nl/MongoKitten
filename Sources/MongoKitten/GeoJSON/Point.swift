//
//  Point.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 07/01/2017.
//
//

import Foundation

public protocol Geometry {
    var type: GeoJsonObjectType { get }
    func toDocument() -> Document
}

/// A single point for a geospatial query
public struct Point: Geometry {

    /// The coordinate this point is located at
    public let coordinate: Position
    
    /// The type of object
    public let type: GeoJsonObjectType = .point

    /// Creates a point from a position on the map
    public init(coordinate: Position) {
        self.coordinate = coordinate
    }

    public func toDocument() -> Document {
        return ["type": self.type.rawValue, "coordinates": [self.coordinate.values[0], self.coordinate.values[1]] as Document ] as Document
    }
}
