 //
//  DatabaseTests.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 21/04/16.
//
//

import XCTest
@testable import MongoKitten
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
        
        try! TestManager.clean()
    }  
    
    override func tearDown() {
        try! TestManager.disconnect()
    }
    
    func testServer() throws {
        XCTAssert(TestManager.server.isConnected)
        
        try TestManager.server.fsync()
        let dbs = try TestManager.server.getDatabases()
        
        var dbExists = false
        
        for db in dbs where db.name == "mongokitten-unittest" {
           dbExists = true
        }
        
        XCTAssertEqual(TestManager.server.hostname, "localhost:27017")
        
        XCTAssert(dbExists)
        
        try TestManager.db.copy(toDatabase: "mongokitten-unittest-temp")
        let _ = try TestManager.server.getDatabaseInfos()
        try TestManager.server["mongokitten-unittest-temp"].drop()
    }
    
    func testDatabase() throws {
        do {
            try TestManager.db.drop(user: "mongokitten-henk")
        } catch {}
        
        try TestManager.db.createUser("mongokitten-henk", password: "banapple", roles: [], customData: ["num": Int32(3)])
        let info = try TestManager.server.getUserInfo(forUserNamed: "mongokitten-henk", inDatabase: TestManager.db)
        XCTAssertEqual(info[0, "customData", "num"] as Int32?, Int32(3))
        
        try TestManager.db.update(user: "mongokitten-henk", password: "banappol", roles: [], customData: ["num": Int32(5)])
        let newInfo = try TestManager.server.getUserInfo(forUserNamed: "mongokitten-henk", inDatabase: TestManager.db)
        XCTAssertEqual(newInfo[0, "customData", "num"] as Int32?, 5)
        
        try TestManager.db.drop(user: "mongokitten-henk")
        
        try TestManager.db.createCollection("test")
        
        var exists = false
        for col in try TestManager.db.listCollections() where col.name == "test" {
            exists = true
        }
        
        try TestManager.db["test"].drop()
        
        XCTAssert(exists)
    }
    
    func testCollection() throws {
        let test = TestManager.db["test"]
        _ = try test.insert(["your": ["int": 3] as Document] as Document)
        try TestManager.db["test"].compact()
        XCTAssertEqual(try test.count(), 1)
        
        XCTAssertEqual(try test.count(matching: "your.int" == 3), 1)
        XCTAssertEqual(try test.count(matching: "your.int" == 4), 0)
        
        XCTAssertEqual(try test.count(matching: nil, skipping: 1), 0)
        
        XCTAssertEqual(test.fullName, "\(TestManager.db.name).test")
    }
}
