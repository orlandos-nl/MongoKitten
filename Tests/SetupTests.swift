//
//  SetupTests.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 23/03/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import MongoKitten
import XCTest

class SetupTests: XCTestCase {
    override func setUp() {
        super.setUp()
        
        do {
            try TestManager.connect()
            try TestManager.dropAllTestingCollections()
        } catch {
            XCTFail("Error while setting up tests: \(error)")
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testSetup() {
        let server = try! Server(client: client, autoConnect: true, authentication: (username: "unittest", password: "unittest-password"))
        let database = server["mongokitten-unittest"]
        let testCollection = database["testcollection"]
        let testBucket = database["bucket.collection"]
        
        XCTAssertEqual(testBucket.database.name, "mongokitten-unittest")
        XCTAssertEqual(database.name, "mongokitten-unittest")
        XCTAssertEqual(testCollection.database.name, "mongokitten-unittest")
    }
    
    func testA() {
        
    }
}