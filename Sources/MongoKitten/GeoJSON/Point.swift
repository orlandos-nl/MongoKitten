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

public struct Point: Geometry {

    let coordinate: Position
    let type: GeoJsonObjectType = .point

    public init(coordinate: Position) {
        self.coordinate = coordinate
    }
}

