//
//  ReadTests.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 01-03-16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import XCTest
import MongoKitten

class ReadTests: XCTestCase {
    lazy var testDatabase = TestManager.testDatabase
    lazy var testCollection = TestManager.testCollection
    lazy var server = TestManager.server

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        do {
            try TestManager.connect()
            try TestManager.fillCollectionWithSampleUsers()
        } catch {
            XCTFail()
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testQuery() {
        let user = TestManager.testingUsers.first!
        
        // FindOne
        do {
            let document = try! testCollection.findOne("_id" == user["_id"]!)
            
            XCTAssertEqual(document?["name"]?.stringValue, user["name"]!.stringValue!)
        }
        
        // Find
        do {
            let documents = Array(try! testCollection.find("_id" == user["_id"]!))
            
            XCTAssert(documents.count == 1)
        }
        
        // Find with nothing to find
        do {
            for _ in  try! testCollection.find(["thiswont":"giveresults"]) {
                XCTFail()
            }
            
            for _ in  try! server["nonexistentdatabase"]["nonexistentcollection"].find() {
                XCTFail()
            }
        }
    }
    
    func testReadmeCode() {
        
    }

}
