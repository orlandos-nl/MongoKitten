//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import XCTest
import MongoKitten
import Dispatch

public class AggregationTests: XCTestCase {
    public static var allTests: [(String, (AggregationTests) -> () throws -> Void)] {
        return [
//            ("testAggregate", testAggregate),
            ("testAggregateLookup", testAggregateLookup)
        ]
    }

//    func testAggregate() throws {
//        let db = TestManager.db
//        let pipeline: AggregationPipeline = [
//        .group("$state", computed: ["totalPop": ["$sum": "$pop"]]),
//            .match("totalPop" > 10_000_000),
//            .sort(["totalPop": .ascending]),
//            .project(["_id": false, "totalPop": true]),
//            .skip(2)
//        ]
//
//        let cursor = db["zips"].aggregate(pipeline)
//
//        var count = 0
//        var previousPopulation = 0
//        for populationDoc in cursor {
//            let population = Int(populationDoc["totalPop"]) ?? -1
//
//            guard population > previousPopulation else {
//                XCTFail()
//                continue
//            }
//
//            guard populationDoc["_id"] == nil else {
//                XCTFail()
//                continue
//            }
//
//            previousPopulation = population
//
//            count += 1
//        }
//
//        XCTAssertEqual(count, 5)
//
//        let pipeline2: AggregationPipeline = [
//            .group("$state", computed: ["totalPop": .sumOf("$pop")]),
//            .match("totalPop" > 10_000_000),
//            .sort(["totalPop": .ascending]),
//            .project(["_id": false, "totalPop": true]),
//            .skip(2),
//            .limit(3),
//            .count(insertedAtKey: "results"),
//            .addFields(["topThree": true])
//        ]
//
//        do {
//            let result = Array(try db["zips"].aggregate(pipeline2)).first
//
//            guard let resultCount = Int(result?["results"]), resultCount == 3, result?["topThree"] as? Bool == true else {
//                XCTFail()
//                return
//            }
//        } catch MongoError.invalidResponse(let response) {
//            XCTAssertEqual(Int(response.first?["code"]), 16436)
//        }
//        // TODO: Test $out, $lookup, $unwind
//    }
//
//    func testFacetAggregate() throws {
//        let db = TestManager.db
//        if let info = db.server.buildInfo, info.version < Version(3, 4, 0) {
//            return
//        }
//
//        let pipeline: AggregationPipeline = [
//            .group("$state", computed: ["totalPop": ["$sum": "$pop"])]),
//            .sort(["totalPop": .ascending]),
//            .facet([
//                "count": [
//                    .count(insertedAtKey: "resultCount"),
//                    .project(["resultCount": true])
//                ],
//                "totalPop": [
//                    .group(Null(), computed: ["population": .sumOf("$totalPop")])
//                ]
//            ])
//        ]
//
//        try db["zips"].aggregate(pipeline).then { cursor in
//            return cursor.next()
//        }.do { doc in
//            XCTAssertEqual(Int(doc["count"][0]["resultCount"]), 51)
//        }.catch { _ in
//            XCTFail()
//        }
//
//        XCTAssertEqual(Int(result["count"][0]["resultCount"]), 51)
//        XCTAssertEqual(Int(result["totalPop"][0]["population"]), 248408400)
//    }

    func testAggregateLookup() throws {
        let db = TestManager.db
        if let info = db.server.buildInfo, info.version < Version(3, 2, 0) {
            return
        }

        let orders = db["orders"]
        let inventory = db["inventory"]

        _ = try? orders.drop().blockingAwait(timeout: .seconds(10))
        _ = try? inventory.drop().blockingAwait(timeout: .seconds(10))

        let orderDocument: Document = ["_id": 1, "item": "MON1003", "price": 350, "quantity": 2, "specs": [ "27 inch", "Retina display", "1920x1080" ], "type": "Monitor"]
        let orderId = try orders.insert(orderDocument).blockingAwait(timeout: .seconds(10))
        XCTAssertEqual(orderId.n, 1)

        let inventoryDocument1: Document = ["_id": 1, "sku": "MON1003", "type": "Monitor", "instock": 120, "size": "27 inch", "resolution": "1920x1080"]
        let inventoryDocument2: Document = ["_id": 2, "sku": "MON1012", "type": "Monitor", "instock": 85, "size": "23 inch", "resolution": "1280x800"]
        let inventoryDocument3: Document = ["_id": 3, "sku": "MON1031", "type": "Monitor", "instock": 60, "size": "23 inch", "display_type": "LED"]

        _ = try inventory.insert(inventoryDocument1).blockingAwait(timeout: .seconds(10))
        _ = try inventory.insert(inventoryDocument2).blockingAwait(timeout: .seconds(10))
        _ = try inventory.insert(inventoryDocument3).blockingAwait(timeout: .seconds(10))

        let unwind = AggregationPipeline.Stage.unwind("$specs")
        let lookup = AggregationPipeline.Stage.lookup(from: inventory, localField: "specs", foreignField: "size", as: "inventory_docs")
        let match = AggregationPipeline.Stage.match(["inventory_docs": ["$ne":[]]])
        let pipe:  AggregationPipeline = [ unwind, lookup, match ]

        do {
            let query = orders.aggregate(pipe)
            
            _ = try query.flatMap(to: Int.self) { cursor in
                var count = 0
                let promise = Promise<Int>()
                
                cursor.drain { upstream in
                    upstream.request(count: .max)
                }.output { document in
                    XCTAssertEqual(String(document["item"]), "MON1003")
                    XCTAssertEqual(Int(document["price"]), 350)
                    XCTAssertEqual([Primitive](document["inventory_docs"])?.count, 1)
                    count += 1
                }.catch(onError: promise.fail).finally {
                    promise.complete(count)
                }
                
                return promise.future
            }.do { count in
                XCTAssertEqual(count, 1)
            }.blockingAwait(timeout: .seconds(10))
        } catch {
            XCTFail()
        }
    }
}


