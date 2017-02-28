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

class AggregationTests: XCTestCase {
    static var allTests: [(String, (AggregationTests) -> () throws -> Void)] {
        return [
            ("testAggregate", testAggregate),
            ("testFacetAggregate", testFacetAggregate),
            ("testAggregateLookup", testAggregateLookup)
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
    
    func testAggregate() throws {
        for db in TestManager.dbs {
            let pipeline: AggregationPipeline = [
                .group("$state", computed: ["totalPop": .sumOf("$pop")]),
                .match("totalPop" > 10_000_000),
                .sort(["totalPop": .ascending]),
                .project(["_id": false, "totalPop": true]),
                .skip(2)
            ]
            
            let cursor = try db["zips"].aggregate(pipeline)
            
            var count = 0
            var previousPopulation = 0
            for populationDoc in cursor {
                let population = Int(populationDoc["totalPop"]) ?? -1
                
                guard population > previousPopulation else {
                    XCTFail()
                    continue
                }
                
                guard populationDoc["_id"] == nil else {
                    XCTFail()
                    continue
                }
                
                previousPopulation = population
                
                count += 1
            }
            
            XCTAssertEqual(count, 5)
            
            let pipeline2: AggregationPipeline = [
                .group("$state", computed: ["totalPop": .sumOf("$pop")]),
                .match("totalPop" > 10_000_000),
                .sort(["totalPop": .ascending]),
                .project(["_id": false, "totalPop": true]),
                .skip(2),
                .limit(3),
                .count(insertedAtKey: "results"),
                .addFields(["topThree": true])
            ]
            
            do {
                let result = Array(try db["zips"].aggregate(pipeline2)).first
                
                guard let resultCount = Int(result?["results"]), resultCount == 3, result?["topThree"] as? Bool == true else {
                    XCTFail()
                    return
                }
            } catch MongoError.invalidResponse(let response) {
                XCTAssertEqual(Int(response.first?["code"]), 16436)
            }
        }
        // TODO: Test $out, $lookup, $unwind
    }
    
    func testFacetAggregate() throws {
        for db in TestManager.dbs {
            if db.server.buildInfo.version < Version(3, 4, 0) {
                return
            }
            
            let pipeline: AggregationPipeline = [
                .group("$state", computed: ["totalPop": .sumOf("$pop")]),
                .sort(["totalPop": .ascending]),
                .facet([
                    "count": [
                        .count(insertedAtKey: "resultCount"),
                        .project(["resultCount": true])
                    ],
                    "totalPop": [
                        .group(Null(), computed: ["population": .sumOf("$totalPop")])
                    ]
                    ])
            ]
            
            guard let result = Array(try db["zips"].aggregate(pipeline)).first else {
                XCTFail()
                return
            }
            
            XCTAssertEqual(Int(result["count"][0]["resultCount"]), 51)
            XCTAssertEqual(Int(result["totalPop"][0]["population"]), 248408400)
        }
    }
    
    func testAggregateLookup() throws {
        for db in TestManager.dbs {
            if db.server.buildInfo.version < Version(3, 2, 0) {
                return
            }
            
            let orders = db["orders"]
            let inventory = db["inventory"]
            
            try orders.drop()
            try inventory.drop()
            
            let orderDocument: Document = ["_id": 1, "item": "MON1003", "price": 350, "quantity": 2, "specs": [ "27 inch", "Retina display", "1920x1080" ], "type": "Monitor"]
            let orderId = try orders.insert(orderDocument)
            XCTAssertEqual(Int(orderId), 1)
            
            let inventoryDocument1: Document = ["_id": 1, "sku": "MON1003", "type": "Monitor", "instock": 120, "size": "27 inch", "resolution": "1920x1080"]
            let inventoryDocument2: Document = ["_id": 2, "sku": "MON1012", "type": "Monitor", "instock": 85, "size": "23 inch", "resolution": "1280x800"]
            let inventoryDocument3: Document = ["_id": 3, "sku": "MON1031", "type": "Monitor", "instock": 60, "size": "23 inch", "display_type": "LED"]
            
            let inventory1 = try inventory.insert(inventoryDocument1)
            let inventory2 = try inventory.insert(inventoryDocument2)
            let inventory3 = try inventory.insert(inventoryDocument3)
            
            XCTAssertEqual(Int(inventory1), 1)
            XCTAssertEqual(Int(inventory2), 2)
            XCTAssertEqual(Int(inventory3), 3)
            
            let unwind = AggregationPipeline.Stage.unwind(atPath: "$specs")
            let lookup = AggregationPipeline.Stage.lookup(from: inventory, localField: "specs", foreignField: "size", as: "inventory_docs")
            let match = AggregationPipeline.Stage.match(["inventory_docs": ["$ne":[]]] as Document)
            let pipe = AggregationPipeline(arrayLiteral: unwind, lookup, match)
            
            do {
                let cursor = try orders.aggregate(pipe)
                let results = Array(cursor)
                XCTAssertEqual(results.count, 1)
                if results.count == 1 {
                    let document = results[0]
                    XCTAssertEqual(String(document["item"]), "MON1003")
                    XCTAssertEqual(Int(document["price"]), 350)
                    XCTAssertEqual([Primitive](document["inventory_docs"])?.count, 1)
                }
            } catch let error as MongoError {
                XCTFail(error.localizedDescription)
            }
        }
    }
}
