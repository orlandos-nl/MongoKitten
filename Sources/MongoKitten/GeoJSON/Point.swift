//
//  Point.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 07/01/2017.
//
//

import Foundation

protocol Geometry {

}

/// A single point for a geospatial query
public struct Point: Geometry {
    /// The coordinate this point is located at
    let coordinate: Position
    
    /// The type of object
    let type: GeoJsonObjectType = .point

    /// Creates a point from a position on the map
    public init(coordinate: Position) {
        self.coordinate = coordinate
    }
}

