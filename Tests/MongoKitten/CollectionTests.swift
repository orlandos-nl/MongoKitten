//
//  CollectionTests.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 23/03/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import XCTest
import MongoKitten

class CollectionTests: XCTestCase {
    static var allTests: [(String, CollectionTests -> () throws -> Void)] {
        return [
                   ("testDistinct", testDistinct),
                   ("testFind", testFind),
                   ("testUpdate", testUpdate),
                   ("testDelete", testDelete),
        ]
    }
    
    override func setUp() {
        super.setUp()
        
        try! TestManager.connect()
        try! TestManager.clean()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testDistinct() {
        let distinct = try! TestManager.db["zips"].distinct("state")!
        
        XCTAssertEqual(distinct.count, 51)
    }
    
    func testFind() {
        let base = *["username": "bob", "age": 25, "kittens": 6, "dogs": 0, "beers": 90]
        
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
        
        _ = try! TestManager.wcol.insert(inserts)
        
        let query: Query = ("username" == "henk" || "username" == "bob") && "age" > 24 && "kittens" >= 2 && "kittens" != 3 && "dogs" <= 1 && "beers" < 100
        
        let response = Array(try! TestManager.wcol.find(matching: query))
        
        let response2 = try! TestManager.wcol.findOne(matching: query)!
        
        XCTAssertEqual(response.count, 2)
        
        XCTAssertEqual(response.first, response2)
    }
    
    func testAggregate() {
        let cursor = try! TestManager.db["zips"].aggregate([
                                             *[ "$group": *[ "_id": "$state", "totalPop": *[ "$sum": "$pop" ] ] ],
                                             *[ "$match": *[ "totalPop": *[ "$gte": 10*1000*1000 ] ] ]
        ])
        
        var count = 0
        for _ in cursor {
            count += 1
        }
        
        XCTAssert(count == 7)
    }
    
    func testUpdate() {
        // TODO: Test update
    }
    
    func testDelete() {
        // TODO: Test delete
    }
}
