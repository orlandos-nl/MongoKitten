//
//  MongoKittenTests.swift
//  MongoKittenTests
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import XCTest
import BSON
@testable import MongoKitten

class MongoKittenTests: XCTestCase {
    var server: Server = try! Server(host: "127.0.0.1", port: 27017, autoConnect: false)
    var database: Database!
    var collection: Collection!
    
    override func setUp() {
        super.setUp()
        
        try! server.connect()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try! server.disconnect()
    }
    
    func testSetup() {
        let server2 = try! Server(host: "127.0.0.1", port: 27017, autoConnect: true)
        
        do {
            // Should fail
            try server2.connect()
            XCTFail()
            
        } catch(_) { }

        
        do {
            // This one should work
            try server2.disconnect()
            
            // This one should NOT work
            try server2.disconnect()
            XCTFail()
        } catch(_) {}
        
        do {
            try server2["test"]["test"].insert(["shouldnt": "beinserted"])
            XCTFail()
        } catch(_) {}
    }
    
    func testSubscripting() {
        database = server["test"]
        collection = database["test"]
        
        if let collectionDatabase: Database = collection.database {
            XCTAssert(collectionDatabase.name == database.name)
            
        } else {
            XCTFail()
        }
    }
    
    func testGeneralSetup() {
        database = server["test"]
        collection = database["test"]
        
        let db2 = server["test"]
        let coll2 = db2["test"]
        
        do {
            _ = try Collection(server: server, fullCollectionName: ".test")
            
            XCTFail()
        } catch(_) {}
        
        if db2.name != database.name {
            XCTFail()
        }
        
        if coll2.name != collection.name {
            XCTFail()
        }
        
        do {
            let _ = try Collection(server: server, fullCollectionName: ".hont")
            XCTFail()
        } catch(_) {}
        
        do {
            let _ = try Database(server: server, databaseName: "")
            XCTFail()
        } catch (_) {}
        
        do {
            let _ = try Collection(database: database, collectionName: "")
            XCTFail()
        } catch(_) {}
    }
    
    func testQuery() {
        database = server["test"]
        collection = database["test"]
        
        try! collection.insert(["query": "test"])
        
        let query: Document = [
            "query": "test"
        ]
        
        let expectation = expectationWithDescription("Trying to get a response to my query")
        
        let queryMsg = try! QueryMessage(collection: collection, query: query, flags: [])
        var done = false
        
        try! server.sendMessage(queryMsg) { reply in
            done = true
            for d in reply.documents {
                print(d)
            }
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(10) { error in
            if !done {
                XCTFail()
            }
        }
    }
    
    func testInsert() {
        database = server["test"]
        collection = database["test"]
        
        try! collection.insert([
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
            ])
        
        try! collection.insertAll([["hont": "kad"], ["fancy": 3.14], ["documents": true]])
        
        let document: Document = ["insert": ["using", "operators"]]
        let response = collection += document
        
        if !response {
            XCTFail()
        }
    }
    
    func testUpdate() {
        database = server["test"]
        collection = database["test"]
        
        try! collection.insert(["honten": "hoien"])
        try! collection.update(["honten": "hoien"], to: ["honten": 3])
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
