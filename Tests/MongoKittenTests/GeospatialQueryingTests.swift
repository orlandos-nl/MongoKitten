//
//  GeospatialOperatorsTests.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 23/01/2017.
//
//

import XCTest
@testable import MongoKitten

class GeospatialQueryingTest: XCTestCase {
    static var allTests: [(String, (GeospatialQueryingTest) -> () throws -> Void)] {
        return [
            ("testGeo2SphereIndex", testGeo2SphereIndex),
            ("testGeoNear", testGeoNear),
            ("testNearQuery", testNearQuery),
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

        // Cleaning
        do {
            for db in TestManager.dbs {
                try db["airports"].drop()
                //try db["GeoCollection"].drop()
            }
        } catch {

        }
        try! TestManager.disconnect()
    }

    func testGeo2SphereIndex() throws {
        loop: for db in TestManager.dbs {
            if db.server.buildInfo.version < Version(3, 2, 0) {
                return
            }

            let airports = db["airports"]
            let jfkAirport: Document = [ "iata": "JFK", "loc":["type":"Point", "coordinates":[-73.778925, 40.639751] as Document] as Document]
            try airports.insert(jfkAirport)
            try airports.createIndex(named: "loc_index", withParameters: .geo2dsphere(field: "loc"))


            for index in try airports.listIndexes() where index["name"] as String? == "loc_index" {
                if let _ = index["2dsphereIndexVersion"] as Int?  {
                    print(index.dictionaryValue)
                    continue loop
                }
            }

            XCTFail()
        }
    }

    func testGeoNear() throws {
        for db in TestManager.dbs {
            let zips = db["zips"]
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

    func testNearQuery() throws {
        for db in TestManager.dbs {
            let zips = db["zips"]
            try zips.createIndex(named: "loc_index", withParameters: .geo2dsphere(field: "loc"))
            let position = try Position(values: [-72.844092,42.466234])
            let query = Query(aqt: .near(key: "loc", point: Point(coordinate: position), maxDistance: 100.0, minDistance: 0.0))

            let results = Array(try zips.find(matching: query))
            if results.count == 1 {
                XCTAssertEqual(results[0][raw: "city"]?.string, "GOSHEN")
            } else {
                XCTFail("Too many results")
            }
        }
    }

    func testGeoWithInQuery() throws {
        let firstPoint: Document = ["geo": Point(coordinate: try Position(values: [1.0, 1.0]))]
        let secondPoint: Document = ["geo": Point(coordinate: try Position(values: [45.0,2.0]))]
        let thirdPoint: Document = ["geo": Point(coordinate: try Position(values: [3.0,3.0]))]

        for db in TestManager.dbs {
            let collection = db["GeoCollection"]
            try collection.insert(firstPoint)
            try collection.insert(secondPoint)
            try collection.insert(thirdPoint)
            try collection.createIndex(named: "geoIndex", withParameters: .geo2dsphere(field: "geo"))

            let polygon = try Polygon(exterior: [Position(values: [0.0, 0.0]), Position(values: [0.0,4.0]),Position(values: [4.0,4.0]), Position(values: [4.0,0.0]), Position(values: [0.0,0.0])])

            let query = Query(aqt: .geoWithin(key: "geo", polygon: polygon))
            print(query.queryDocument)
            do {
                let results = Array(try collection.find(matching: query))
                print(results)
            } catch MongoError.invalidResponse(let documentError) {
                print(documentError)
                XCTFail(documentError.first?[raw: "errmsg"]?.string ?? "")
            }
        }
    }
}
