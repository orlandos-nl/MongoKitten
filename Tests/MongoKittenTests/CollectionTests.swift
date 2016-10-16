//
//  CollectionTests.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 23/03/16.
//  Copyright © 2016 OpenKitten. All rights reserved.
//

import XCTest
import MongoKitten
import Cryptography
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
        
        try! TestManager.connect()
        try! TestManager.clean()
    }
    
    override func tearDown() {
        try! TestManager.disconnect()
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testDistinct() throws {
        let distinct = try TestManager.db["zips"].distinct(onField: "state")!
        
        XCTAssertEqual(distinct.count, 51)
    }
    
    func testPerformance() throws {
        let collection = TestManager.db["zips"]
        var documents = [Document]()
        documents.reserveCapacity(29353)
        
        func testQueue(max: Int = 10) {
            let perQueue = 25_000 / max
            
            for i in 0..<max {
                let start = i * perQueue
                
                let q = DispatchQueue(label: "org.openkitten.tests.performance.\(i)")
                let e = expectation(description: "kaas \(i)")
                
                q.async {
                    for j in start..<start+perQueue {
                        _ = try! collection.findOne(skipping: Int32(j))
                    }
                    
                    e.fulfill()
                }
            }
        }
        
        testQueue()
        
        waitForExpectations(timeout: 300)
    }
    
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
        try runStartsWithQuery()
        try runEndsWithQuery()
    }
    
    private func runContainsQuery() throws {
        let query = Query(aqt: .contains(key: "username", val: "ar"))
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
    
    func testAggregate() throws {
        let cursor = try TestManager.db["zips"].aggregate(pipeline: [
                                             [ "$group": [ "_id": "$state", "totalPop": [ "$sum": "$pop" ] ] ],
                                             [ "$match": [ "totalPop": [ "$gte": ~10_000_000 ] ] ]
        ])
        
        var count = 0
        for _ in cursor {
            count += 1
        }
        
        XCTAssert(count == 7)
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
}
