//
//  DatabaseTests.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 21/04/16.
//
//

import XCTest
import MongoKitten
import BSON

class AdministrationCommandsTests: XCTestCase {
    static var allTests: [(String, (AdministrationCommandsTests) -> () throws -> Void)] {
        return [
                   ("testServer", testServer),
                   ("testDatabase", testDatabase),
                   ("testCollection", testCollection),
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
    
    func testServer() {
        try! TestManager.server.fsync()
        let dbs = try! TestManager.server.getDatabases()
        
        var dbExists = false
        
        for db in dbs where db.name == "mongokitten-unittest" {
           dbExists = true
        }
        
        XCTAssert(dbExists)
        
        try! TestManager.db.copy(to: "mongokitten-unittest-temp")
        let _ = try! TestManager.server.getDatabaseInfos()
        try! TestManager.server["mongokitten-unittest-temp"].drop()
    }
    
    func testDatabase() {
        do {
            try TestManager.db.drop(user: "mongokitten-henk")
        } catch {}
        
        try! TestManager.db.createUser("mongokitten-henk", password: "banapple", roles: [], customData: ["num": .int32(3)])
        let info = try! TestManager.server.info(for: "mongokitten-henk", inDatabase: TestManager.db)
        XCTAssertEqual(info[0]["customData"]["num"].int32Value, 3)
        
        try! TestManager.db.update(user: "mongokitten-henk", password: "banappol", roles: [], customData: ["num": .int32(5)])
        let newInfo = try! TestManager.server.info(for: "mongokitten-henk", inDatabase: TestManager.db)
        XCTAssertEqual(newInfo[0]["customData"]["num"].int32Value, 5)
        
        try! TestManager.db.drop(user: "mongokitten-henk")
        
        try! TestManager.db.createCollection("test")
        
        var exists = false
        for col in try! TestManager.db.getCollections() where col.name == "test" {
            exists = true
        }
        
        try! TestManager.db["test"].drop()
        
        XCTAssert(exists)
    }
    
    func testCollection() {
        let test = TestManager.db["test"]
        _ = try! test.insert(["your": ["int": 3]])
        try! TestManager.db["test"].compact()
        XCTAssertEqual(try! test.count(), 1)
        
        XCTAssertEqual(try! test.count(matching: "your.int" == 3), 1)
        XCTAssertEqual(try! test.count(matching: "your.int" == 4), 0)
        
        XCTAssertEqual(try! test.count(matching: nil, skipping: 1), 0)
        
        XCTAssertEqual(test.fullName, "\(TestManager.db.name).test")
    }
}
