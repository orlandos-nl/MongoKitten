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


extension Collection {
    /// Returns documents in order of proximity to a specified point, from the nearest to farthest. geoNear requires a geospatial index.
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/geoNear/
    ///
    /// - parameter options: Geo Near options
    /// - parameter readConcern: Specifies the read concern.
    /// - returns: a Document with the results
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func geoNear(options: GeoNearOptions, readConcern: ReadConcern? = nil) throws -> Document {
        var command: Document = ["geoNear": self.name,
         "near": options.near,
         "spherical": options.spherical,
         "distanceField": options.distanceField,
         "limit": options.limit,
         "minDistance": options.minDistance,
         "maxDistance": options.maxDistance,
         "query": options.query,
         "distanceMultiplier": options.distanceMultiplier,
         "uniqueDocs": options.uniqueDocs,
         "includeLocs": options.includeLocs]

        command["readConcern"] = readConcern ?? self.readConcern

        let reply = try database.execute(command: command, writing: false)

        guard let responseDoc = reply.documents.first, Int(responseDoc["ok"]) == 1 else {
            log.error("The geographical 'geoNear' query failed")
            log.error(reply.documents.first ?? [:])
            throw MongoError.invalidResponse(documents: reply.documents)
        }

        return try firstDocument(in: reply)
    }
}
