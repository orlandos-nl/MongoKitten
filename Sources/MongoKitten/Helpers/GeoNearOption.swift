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
import GeoJSON

/// Requires the resulting data to be near the provided point
///
/// Also allows further configuration of the query
///
/// Further information and details: https://docs.mongodb.com/manual/reference/command/geoNear/
public struct GeoNearOption: ValueConvertible {
    /// The point which you're looking near
    public let near: Point

    /// The output field that contains the calculated distance.
    public let distanceField: String

    /// If true, then MongoDB uses spherical geometry to calculate distances in meters if the specified (near) point is a GeoJSON point and in radians if the specified (near) point is a legacy coordinate pair.
    ///
    /// If false, then MongoDB uses 2d planar geometry to calculate distance between points.
    public let spherical: Bool

    /// Limits the returned results
    ///
    /// 100 by default
    public let limit: Int?

    /// The minimum distance from the center point resulting Documents must be
    public let minDistance: Double?

    /// The maximum distance from the center point resulting Documents must be
    public let maxDistance: Double?

    /// Requires resulting documents to also match this query, besides the geolocation query
    public let query: Query?

    /// The factor to multiply all distances returned by the query. For example, use the distanceMultiplier to convert radians, as returned by a spherical query, to kilometers by multiplying by the radius of the Earth.
    public let distanceMultiplier: Double?

    /// Outputs each matching document once, even if multiple fields match the query
    ///
    /// Deprecated in 2.6
    public let uniqueDocs: Bool?

    /// This specifies the output field that identifies the location used to calculate the distance.
    public let includeLocs: String?

    /// Creates GeoNear options
    public init(near: Point, spherical: Bool, distanceField: String, limit: Int? = nil, minDistance: Double? = nil, maxDistance: Double? = nil, query: Query? = nil, distanceMultiplier: Double? = nil, uniqueDocs: Bool? = nil, includeLocs: String? = nil) {
        self.near = near
        self.spherical = spherical
        self.distanceField = distanceField
        self.limit = limit
        self.minDistance = minDistance
        self.maxDistance = maxDistance
        self.query = query
        self.distanceMultiplier = distanceMultiplier
        self.uniqueDocs = uniqueDocs
        self.includeLocs = includeLocs
    }

    /// Creates a Document for these options
    public func makeDocument() -> Document {
        return ["near":near,
                "spherical": spherical,
                "distanceField": distanceField,
                "limit": limit,
                "minDistance": minDistance,
                "maxDistance": maxDistance,
                "query": query,
                "distanceMultiplier": distanceMultiplier,
                "uniqueDocs": uniqueDocs,
                "includeLocs": includeLocs]
    }

    /// Makes this an embeddable primitive
    public func makeBSONPrimitive() -> BSONPrimitive {
        return makeDocument()
    }
}
