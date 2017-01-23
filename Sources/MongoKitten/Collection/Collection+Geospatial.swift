//
//  Collection+Geospatial.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 23/01/2017.
//
//

import Foundation


extension Collection {

    /// Returns documents in order of proximity to a specified point, from the nearest to farthest. geoNear requires a geospatial index.
    ///
    /// - parameters:
    ///   - options: Geo Near options
    ///   - readConcern: Specifies the read concern.
    /// - returns: a Document with the results
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    /// - SeeAlso : https://docs.mongodb.com/manual/reference/command/geoNear/
    func near(options: GeoNearOption, readConcern: ReadConcern? = nil) throws -> Document {
        var command: Document = ["geoNear": self.name,
         "near":options.near,
         "spherical": options.spherical,
         "distanceField": options.distanceField,
         "limit": options.limit,
         "minDistance": options.minDistance,
         "maxDistance": options.maxDistance,
         "query": options.query,
         "distanceMultiplier": options.distanceMultiplier,
         "uniqueDocs": options.uniqueDocs,
         "includeLocs": options.includeLocs]

        command[raw: "readConcern"] = readConcern ?? self.readConcern

        let reply = try database.execute(command: command, writing: false)


        guard case .Reply(_, _, _, _, _, _, let documents) = reply else {
            throw InternalMongoError.incorrectReply(reply: reply)
        }

        guard let responseDoc = documents.first, responseDoc[raw: "ok"]?.int == 1 else {
            throw MongoError.invalidResponse(documents: documents)
        }

        return try firstDocument(in: reply)
    }
}
