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
import BSON

public class AdministrationCommandsTests: XCTestCase {
    public static var allTests: [(String, (AdministrationCommandsTests) -> () throws -> Void)] {
        return [
                   ("testServer", testServer),
                   ("testDatabase", testDatabase),
                   ("testCollection", testCollection),
        ]
    }
    
    public override func setUp() {
        super.setUp()
        
        try! TestManager.clean()
    }  
    
    public override func tearDown() {
        try! TestManager.disconnect()
    }
    
    func testServer() throws {
        for db in TestManager.dbs {
            XCTAssert(db.server.isConnected)
            
            var dbExists = false
            
            for serverDB in db.server where serverDB.name == "mongokitten-unittest" {
                dbExists = true
            }
            
            XCTAssert(dbExists)
            
            try db.server["mongokitten-unittest-temp"].drop()
            try db.copy(toDatabase: "mongokitten-unittest-temp")
            let _ = try db.server.getDatabaseInfos()
        }
    }
    
    func testDatabase() throws {
        for db in TestManager.dbs {
            try db.createUser("mongokitten-henk", password: "banapple", roles: [], customData: ["num": Int32(3)])
            let info = try db.server.getUserInfo(forUserNamed: "mongokitten-henk", inDatabase: db)
            XCTAssertEqual(Int32(info[0]["customData"]["num"]), Int32(3))
            
            try db.update(user: "mongokitten-henk", password: "banappol", roles: [], customData: ["num": Int32(5)])
            let newInfo = try db.server.getUserInfo(forUserNamed: "mongokitten-henk", inDatabase: db)
            XCTAssertEqual(Int32(newInfo[0]["customData"]["num"]), 5)
            
            try db.drop(user: "mongokitten-henk")
            
            try db.createCollection(named: "test")
            
            var exists = false
            for col in try db.listCollections() where col.name == "test" {
                exists = true
            }
            
            try db["test"].drop()
            
            XCTAssert(exists)
        }
    }
    
    func testCollection() throws {
        for db in TestManager.dbs {
            let test = db["test"]
            _ = try test.insert(["your": ["int": 3]])
            try db["test"].compact()
            XCTAssertEqual(try test.count(), 1)
            
            XCTAssertEqual(try test.count("your.int" == 3), 1)
            XCTAssertEqual(try test.count("your.int" == 4), 0)
            
            XCTAssertEqual(try test.count(nil, skipping: 1), 0)
            
            XCTAssertEqual(test.fullName, "\(db.name).test")
        }
    }
}
