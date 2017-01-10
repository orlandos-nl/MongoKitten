//
//  LineString.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 09/01/2017.
//
//

import Foundation

struct LineString: Geometry {

    public let coordinates: [Position]
    public let type: GeoJsonObjectType = .lineString

    public init(coordinates: [Position]) throws  {
        guard coordinates.count < 2 else { throw GeoJSONError.coordinatesMustContainTwoOrMoreElements }
        self.coordinates = coordinates
    }

    public func toDocument() -> Document {
        let coords = coordinates.map { [$0.values[0],$0.values[1]] as Document }
        return ["type": self.type.rawValue, "coordinates": Document(array: coords) ] as Document
    }

}

