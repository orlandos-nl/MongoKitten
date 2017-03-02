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

