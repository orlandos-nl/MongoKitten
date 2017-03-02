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
