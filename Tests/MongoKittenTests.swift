//
//  MongoKittenTests.swift
//  MongoKittenTests
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import XCTest
import BSON
import When
@testable import MongoKitten

class MongoKittenTests: XCTestCase {
    var server: Server = try! Server(host: "127.0.0.1", port: 27017, autoConnect: false)
    var database: Database!
    var collection: Collection!
    
    override func setUp() {
        super.setUp()
        
        try! !>server.connect()
        
        try! !>server["test"]["test"].remove([])
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try! server.disconnect()
    }
    
    func testSetup() {
        let server2 = try! Server(host: "127.0.0.1", port: 27017, autoConnect: true)
        
        do {
            // Should fail
            try !>server2.connect()
            XCTFail()
            
        } catch(_) { }
        
        do {
            // This one should work
            try server2.disconnect()
            
            // This one should NOT work
            try server2.disconnect()
            XCTFail()
        } catch(_) {}
        
        server2["test"]["test"].insert(["shouldnt": "beinserted"]).then { _ in
            XCTFail()
            }.onError { _ in
        }
    }
    
    func testSubscripting() {
        database = server["test"]
        collection = database["test"]
        
        if let collectionDatabase: Database = collection.database {
            XCTAssert(collectionDatabase.name == database.name)
            XCTAssert(collection.fullName == "test.test")
            
        } else {
            XCTFail()
        }
    }
    
    func testGeneralSetup() {
        database = server["test"]
        collection = database["test"]
        
        let db2 = server["test"]
        let coll2 = db2["test"]
        
        if db2.name != database.name {
            XCTFail()
        }
        
        if coll2.name != collection.name {
            XCTFail()
        }
    }
    
    func testQuery() {
        database = server["test"]
        collection = database["test"]
        
        collection.insert(["query": "test"])
        collection.insertAll([["double": 2], ["double": 2]])
        
        let expectation1 = expectationWithDescription("Getting one document")
        let expectation2 = expectationWithDescription("Getting two documents")
        
        var done1 = false
        var done2 = false
        
        collection.findOne(["query": "test"]).then { document in
            XCTAssert(document!["query"] as! String == "test")
            expectation1.fulfill()
            done1 = true
            }.onError { error in
                XCTFail()
        }
        
        collection.find(["double": 2]).then { documents in
            XCTAssert(documents.count == 2)
            
            for document in documents{
                XCTAssert(document["double"] as! Int == 2)
            }
            
            expectation2.fulfill()
            done2 = true
            }.onError { error in
                XCTFail()
        }
        
        waitForExpectationsWithTimeout(1) { error in
            if !done1 || !done2 {
                XCTFail()
            }
        }
    }
    
    func testInsert() {
        database = server["test"]
        collection = database["test"]
        
        collection.insert([
            "double": 53.2,
            "64bit-integer": 52,
            "32bit-integer": Int32(20),
            "embedded-document": *["double": 44.3, "_id": ObjectId()],
            "embedded-array": *[44, 33, 22, 11, 10, 9],
            "identifier": ObjectId(),
            "datetime": NSDate(),
            "bool": false,
            "null": Null(),
            "binary": Binary(data: [0x01, 0x02]),
            "string": "Hello, I'm a string!"
            ]).onError { _ in
                XCTFail()
        }
        
        collection.insert([["hont": "kad"], ["fancy": 3.14], ["documents": true]]).onError { _ in
            XCTFail()
        }
        
        let document: Document = ["insert": ["using", "operators"]]
        collection.insert(document).onError { _ in
            XCTFail()
        }
    }
    
    func testUpdate() {
        database = server["test"]
        collection = database["test"]
        
        try! !>collection.insert(["honten": "hoien"])
        try! !>collection.find(["honten": "hoien"])
        try! !>collection.update(["honten": "hoien"], updated: ["honten": 3])
    }
}
