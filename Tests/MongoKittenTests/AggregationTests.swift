//
//  AggregationTests.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 17/01/2017.
//
//


import XCTest
import MongoKitten
import CryptoKitten
import Dispatch

class AggregationTests: XCTestCase {
    static var allTests: [(String, (AggregationTests) -> () throws -> Void)] {
        return [
            ("testGeoNear", testGeoNear)
        ]
    }

    override func setUp() {
        super.setUp()
        do {
            try TestManager.clean()
        } catch {
            fatalError("\(error)")
        }
    }

    override func tearDown() {

        try! TestManager.disconnect()
    }

    func testGeoNear() throws {
        let zips = TestManager.db["zips"]
        try zips.createIndex(named: "loc_index", withParameters: .geo2dsphere(field: "loc"))
        let position = try Position(values: [-72.844092,42.466234])
        let near = Point(coordinate: position)

        let geoNearOption = GeoNearOption(near: near, spherical: true, distanceField: "dist.calculated", maxDistance: 10000.0)

        let geoNearStage = AggregationPipeline.Stage.geoNear(geoNearOption: geoNearOption)

        let pipeline: AggregationPipeline = [geoNearStage]

        let results = Array(try zips.aggregate(pipeline: pipeline))

        XCTAssertEqual(results.count, 6)
    }

}
