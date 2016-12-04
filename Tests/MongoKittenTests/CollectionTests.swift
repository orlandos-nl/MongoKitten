//
//  CollectionTests.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 23/03/16.
//  Copyright © 2016 OpenKitten. All rights reserved.
//

import XCTest
import MongoKitten
import CryptoKitten
import Dispatch

class CollectionTests: XCTestCase {
    static var allTests: [(String, (CollectionTests) -> () throws -> Void)] {
        return [
                   ("testDistinct", testDistinct),
                   ("testFind", testFind),
                   ("testUpdate", testUpdate),
                   ("testRemovingAll", testRemovingAll),
                   ("testRemovingOne", testRemovingOne),
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
    
    func testQuery() throws {
        let query: Query = "name_first" == "Henk"
        
        XCTAssertEqual(query.makeDocument(), [
            "name_first": ["$eq": "Henk"] as Document
            ])
        
        let query2: Query = "textSearchTerm"
        
        XCTAssertEqual(query2.makeDocument(), ["$text": [
            "$search": "textSearchTerm",
            "$caseSensitive": false,
            "$diacriticSensitive": false
            ] as Document
            ])
    }
    
    func testRename() throws {
        try TestManager.db["zips"].rename(to: "zipschange")
        
        let pipeline: Pipeline = [
            .grouping("$state", computed: ["totalPop": .sumOf("$pop")]),
            .matching("totalPop" > 10_000_000),
            .sortedBy(["totalPop": .ascending]),
            .projecting(["_id": false, "totalPop": true]),
            .skipping(2)
        ]
        
        var zipsDocs = Array(try TestManager.db["zips"].aggregate(pipeline: pipeline))
        XCTAssertEqual(zipsDocs.count, 0)
        
        zipsDocs = Array(try TestManager.db["zipschange"].aggregate(pipeline: pipeline))
        XCTAssertEqual(zipsDocs.count, 5)
        
        try TestManager.db["zipschange"].rename(to: "zips")
        
        zipsDocs = Array(try TestManager.db["zips"].aggregate(pipeline: pipeline))
        XCTAssertEqual(zipsDocs.count, 5)
        
        zipsDocs = Array(try TestManager.db["zipschange"].aggregate(pipeline: pipeline))
        XCTAssertEqual(zipsDocs.count, 0)
    }
    
    func testDistinct() throws {
        let distinct = try TestManager.db["zips"].distinct(onField: "state")!
        
        XCTAssertEqual(distinct.count, 51)
    }
    
//    func testPerformance() throws {
//        let collection = TestManager.db["zips"]
//        var documents = [Document]()
//        documents.reserveCapacity(29353)
//        
//        func testQueue(max: Int = 10) {
//            let perQueue = 25_000 / max
//            
//            for i in 0..<max {
//                let start = i * perQueue
//                
//                let q = DispatchQueue(label: "org.openkitten.tests.performance.\(i)")
//                let e = expectation(description: "kaas \(i)")
//                
//                q.async {
//                    for j in start..<start+perQueue {
//                        _ = try! collection.findOne(skipping: Int32(j))
//                    }
//                    
//                    e.fulfill()
//                }
//            }
//        }
//        
//        testQueue()
//        
//        waitForExpectations(timeout: 300)
//    }
    
    func testFind() throws {
        let base: Document = ["username": "bob", "age": 25, "kittens": 6, "dogs": 0, "beers": 90]
        
        var inserts: [Document]
        
        var brokenUsername = base
        var brokenAge = base
        var brokenKittens = base
        var brokenKittens2 = base
        var brokenDogs = base
        var brokenBeers = base
        
        brokenUsername["username"] = "harrie"
        brokenAge["age"] = 24
        brokenKittens["kittens"] = 3
        brokenKittens2["kittens"] = 1
        brokenDogs["dogs"] = 2
        brokenBeers["beers"] = "broken"
        
        inserts = [base, brokenUsername, brokenUsername, brokenAge, brokenDogs, brokenKittens, brokenKittens2, brokenBeers, base]
        
        _ = try TestManager.wcol.insert(inserts)
        
        let query: Query = ("username" == "henk" || "username" == "bob") && "age" > 24 && "kittens" >= 2 && "kittens" != 3 && "dogs" <= 1 && "beers" < 100
        
        let response = Array(try TestManager.wcol.find(matching: query))
        
        let response2 = try TestManager.wcol.findOne(matching: query)!
        
        XCTAssertEqual(response.count, 2)
        
        XCTAssertEqual(response.first, response2)
        
        try runContainsQuery()
        try runContainsCaseInsensitiveQuery()
        try runStartsWithQuery()
        try runEndsWithQuery()
    }
    
    func testDBRef() throws {
        let colA = TestManager.db["collectionA"]
        let colB = TestManager.db["collectionB"]
        
        let id = try colA.insert(["name": "Harrie Bob"] as Document)
        
        let dbref = DBRef(referencing: id, inCollection: colA)
        
        let referenceID = try colB.insert(["reference": dbref] as Document)
        
        guard let reference = try colB.findOne(matching: "_id" == referenceID) else {
            XCTFail()
            return
        }
        
        guard let colAreference = DBRef(reference["reference"] as Document? ?? [:], inDatabase: TestManager.db) else {
            XCTFail()
            return
        }
        
        guard let originalDocument = try colAreference.resolve() else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(originalDocument["name"] as String?, "Harrie Bob")
    }
    
    func testProjection() {
        let projection: Projection = ["name", "age", "awesome"]
        
        XCTAssertEqual(projection.makeBSONPrimitive() as? Document, ["name": true, "age": true, "awesome": true] as Document)
        
        let projection2: Projection = ["henk": .included, "bob": .excluded]
        
         XCTAssertEqual(projection2.makeBSONPrimitive() as? Document, ["henk": true, "bob": false])
    }
    
    func testIndexes() throws {
        try TestManager.wcol.createIndex(named: "henkbob", withParameters: .sortedCompound(fields: [("name", .ascending), ("age", .descending)]), .expire(afterSeconds: 1), .buildInBackground)
        
        for index in try TestManager.wcol.listIndexes() where index["name"] as String? == "henkbob" {
            return
        }
        
        XCTFail()
    }
    
    private func runContainsQuery() throws {
        let query = Query(aqt: .contains(key: "username", val: "ar", options: []))
        let response = Array(try TestManager.wcol.find(matching: query))
        XCTAssert(response.count == 2)
    }
    
    private func runStartsWithQuery() throws {
        let query = Query(aqt: .startsWith(key: "username", val: "har"))
        let response = Array(try TestManager.wcol.find(matching: query))
        XCTAssert(response.count == 2)
    }
    
    private func runEndsWithQuery() throws {
        let query = Query(aqt: .endsWith(key: "username", val: "rrie"))
        let response = Array(try TestManager.wcol.find(matching: query))
        XCTAssert(response.count == 2)
    }
    
    private func runContainsCaseInsensitiveQuery() throws {
        let query = Query(aqt: .contains(key: "username", val: "AR", options: .caseInsensitive))
        let response = Array(try TestManager.wcol.find(matching: query))
        XCTAssert(response.count == 2)
    }

    func testAggregate() throws {
        let pipeline: Pipeline = [
            .grouping("$state", computed: ["totalPop": .sumOf("$pop")]),
            .matching("totalPop" > 10_000_000),
            .sortedBy(["totalPop": .ascending]),
            .projecting(["_id": false, "totalPop": true]),
            .skipping(2)
        ]
        
        let cursor = try TestManager.db["zips"].aggregate(pipeline: pipeline)
        
        var count = 0
        var previousPopulation = 0
        for populationDoc in cursor {
            let population = populationDoc["totalPop"] as Int? ?? -1
            
            guard population > previousPopulation else {
                XCTFail()
                continue
            }
            
            guard populationDoc[raw: "_id"] == nil else {
                XCTFail()
                continue
            }
            
            previousPopulation = population
            
            count += 1
        }
        
        XCTAssertEqual(count, 5)
        
        let pipeline2: Pipeline = [
            .grouping("$state", computed: ["totalPop": .sumOf("$pop")]),
            .matching("totalPop" > 10_000_000),
            .sortedBy(["totalPop": .ascending]),
            .projecting(["_id": false, "totalPop": true]),
            .skipping(2),
            .limitedTo(3),
            .counting(insertedAtKey: "results"),
            .addingFields(["topThree": true])
        ]
        
        let result = Array(try TestManager.db["zips"].aggregate(pipeline: pipeline2)).first
        
        guard let resultCount = result?["results"] as Int?, resultCount == 3, result?["topThree"] as Bool? == true else {
            XCTFail()
            return
        }
        
        // TODO: Test $out, $lookup, $unwind
    }
    
    func testFacetAggregate() throws {
        let pipeline: Pipeline = [
            .grouping("$state", computed: ["totalPop": .sumOf("$pop")]),
            .sortedBy(["totalPop": .ascending]),
            .facet([
                    "count": [
                        .counting(insertedAtKey: "resultCount"),
                        .projecting(["resultCount": true])
                    ],
                    "totalPop": [
                        .grouping(Null(), computed: ["population": .sumOf("$totalPop")])
                    ]
                ])
        ]
        
        guard let result = Array(try TestManager.db["zips"].aggregate(pipeline: pipeline)).first else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result["count", 0, "resultCount"] as Int?, 51)
        XCTAssertEqual(result["totalPop", 0, "population"] as Int?, 248408400)
    }
    
    func testTextOperator() throws {
        let textSearch = TestManager.db["textsearch"]
        try textSearch.createIndex(named: "subject", withParameters: .text(["subject"]))
        
        try textSearch.remove(matching: Query([:]))
        
        try textSearch.insert([
            ["_id": 1, "subject": "coffee", "author": "xyz", "views": 50] as Document,
            ["_id": 2, "subject": "Coffee Shopping", "author": "efg", "views": 5] as Document,
            ["_id": 3, "subject": "Baking a cake", "author": "abc", "views": 90] as Document,
            ["_id": 4, "subject": "baking", "author": "xyz", "views": 100] as Document,
            ["_id": 5, "subject": "Café Con Leche", "author": "abc", "views": 200] as Document,
            ["_id": 6, "subject": "Сырники", "author": "jkl", "views": 80] as Document,
            ["_id": 7, "subject": "coffee and cream", "author": "efg", "views": 10] as Document,
            ["_id": 8, "subject": "Cafe con Leche", "author": "xyz", "views": 10] as Document
            ])
        
        let resultCount = try textSearch.count(matching: .textSearch(forString: "coffee"))
        
        XCTAssertEqual(resultCount, 3)
    }
    
    func testUpdate() throws {
        let base: Document = ["username": "bob", "age": 25, "kittens": 6, "dogs": 0, "beers": 90]
        
        var inserts: [Document]
        
        var brokenUsername = base
        var brokenAge = base
        var brokenKittens = base
        var brokenKittens2 = base
        var brokenDogs = base
        var brokenBeers = base
        
        brokenUsername["username"] = "harrie"
        brokenAge["age"] = 24
        brokenKittens["kittens"] = 3
        brokenKittens2["kittens"] = 1
        brokenDogs["dogs"] = 2
        brokenBeers["beers"] = "broken"
        
        inserts = [base, brokenUsername, brokenUsername, brokenAge, brokenDogs, brokenKittens, brokenKittens2, brokenBeers, base]
        try TestManager.wcol.insert(inserts)
        
        let query: Query = ("username" == "henk" || "username" == "bob") && "age" > 24 && "kittens" >= 2 && "kittens" != 3 && "dogs" <= 1 && "beers" < 100
        
        try TestManager.wcol.update(matching: query, to: ["testieBool": true])
        
        try TestManager.server.fsync()
        
        let response = Array(try TestManager.wcol.find(matching: "testieBool" == true))
        XCTAssertEqual(response.count, 1)
        
        let response2 = Array(try TestManager.wcol.find(matching: query))
        XCTAssertEqual(response2.count, 1)
    }
    
    func testRemovingAll() throws {
        let base: Document = ["username": "bob", "age": 25, "kittens": 6, "dogs": 0, "beers": 90]
        
        var inserts: [Document]
        
        var brokenUsername = base
        var brokenAge = base
        var brokenKittens = base
        var brokenKittens2 = base
        var brokenDogs = base
        var brokenBeers = base
        
        brokenUsername["username"] = "harrie"
        brokenAge["age"] = 24
        brokenKittens["kittens"] = 3
        brokenKittens2["kittens"] = 1
        brokenDogs["dogs"] = 2
        brokenBeers["beers"] = "broken"
        
        inserts = [base, brokenUsername, brokenUsername, brokenAge, brokenDogs, brokenKittens, brokenKittens2, brokenBeers, base]
        
        _ = try TestManager.wcol.insert(inserts)
        
        let query: Query = ("username" == "henk" || "username" == "bob") && "age" > 24 && "kittens" >= 2 && "kittens" != 3 && "dogs" <= 1 && "beers" < 100
        
        XCTAssertGreaterThan(try TestManager.wcol.remove(matching: query), 0)
        
        let response = Array(try TestManager.wcol.find(matching: query))
        
        XCTAssertEqual(response.count, 0)
    }
    
    func testRemovingOne() throws {
        let base: Document = ["username": "bob", "age": 25, "kittens": 6, "dogs": 0, "beers": 90]
        
        var inserts: [Document]
        
        var brokenUsername = base
        var brokenAge = base
        var brokenKittens = base
        var brokenKittens2 = base
        var brokenDogs = base
        var brokenBeers = base
        
        brokenUsername["username"] = "harrie"
        brokenAge["age"] = 24
        brokenKittens["kittens"] = 3
        brokenKittens2["kittens"] = 1
        brokenDogs["dogs"] = 2
        brokenBeers["beers"] = "broken"
        
        inserts = [base, brokenUsername, brokenUsername, brokenAge, brokenDogs, brokenKittens, brokenKittens2, brokenBeers, base]
        
        try TestManager.wcol.insert(inserts)
        
        let query: Query = ("username" == "henk" || "username" == "bob") && "age" > 24 && "kittens" >= 2 && "kittens" != 3 && "dogs" <= 1 && "beers" < 100
        
        XCTAssertEqual(try TestManager.wcol.remove(matching: query, limitedTo: 1), 1)
        try TestManager.server.fsync()
        
        let response = Array(try TestManager.wcol.find(matching: query))
        
        XCTAssertEqual(response.count, 1)
    }
    
    func testHelperObjects() {
        let document = [
            "henk": 1 as Int32,
            "klaas": -1 as Int32,
            "roekoe": 1 as Int32
        ] as Document
        let sort = Sort(document)
        
        XCTAssertEqual(document, sort.makeDocument())
        
        let sort2: Sort = [
            "date": .ascending,
            "name": .descending,
            "kaas": .custom(true)
        ]
        
        XCTAssertEqual(sort2.makeDocument(), [
            "date": Int32(1),
            "name": Int32(-1),
            "kaas": true
            ])
    }
}
