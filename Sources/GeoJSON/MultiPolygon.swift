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

/// An group of polygons
public struct MultiPolygon: Geometry {
    /// The polygons array
    public let coordinates: [Polygon]
    
    /// The type name of this geometric object
    public let type: GeoJsonObjectType = .multiPolygon

    /// Creates a new MultiPolygon object
    public init(coordinates: [Polygon]) {
        self.coordinates = coordinates
    }
}

extension MultiPolygon: ValueConvertible {
    /// Converts this object to an embeddable BSONPrimtive
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type": self.type.rawValue, "coordinates": Document(array: self.coordinates) ] as Document
    }
}
