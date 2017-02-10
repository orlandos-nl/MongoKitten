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
@testable import MongoKitten

class DatabaseTests: XCTestCase {
    static var allTests: [(String, (DatabaseTests) -> () throws -> Void)] {
        return [
            ("testUsers", testUsers),
            ("testMakeGridFS", testMakeGridFS),
            ("testPing", testPing),
        ]
    }
    
    override func setUp() {
        super.setUp()
        
        try! TestManager.clean()
    }
    
    override func tearDown() {
       try! TestManager.disconnect()
    }
    
    func testUsers() throws {
        for db in TestManager.dbs {
            let roles: Document = [["role": "dbOwner", "db": db.name] as Document]
            
            try db.createUser("mongokitten-unittest-testuser", password: "hunter2", roles: roles, customData: ["testdata": false])
            
            guard let userInfo = try? db.server.getUserInfo(forUserNamed: "mongokitten-unittest-testuser", inDatabase: db), let testData = userInfo[0, "customData", "testdata"] as Bool? else {
                XCTFail()
                return
            }
            
            XCTAssertEqual(testData, false)
            
            try db.update(user: "mongokitten-unittest-testuser", password: "hunter2", roles: roles, customData: ["testdata": true])
            
            try db.drop(user: "mongokitten-unittest-testuser")
        }
    }
    
    func testMakeGridFS() throws {
        for db in TestManager.dbs {
            let gridFS = try db.makeGridFS()
            
            let id = try gridFS.store(data: [0x05, 0x04, 0x01, 0x02, 0x03, 0x00])
            guard let file = try gridFS.findOne(byID: id) else {
                XCTFail()
                return
            }
            
            XCTAssertEqual(try file.read(), [0x05, 0x04, 0x01, 0x02, 0x03, 0x00])
            
            XCTAssertThrowsError(try file.read(from: -1, to: 7))
            XCTAssertThrowsError(try file.read(from: -1, to: 5))
            
            // TODO: XCTAssertThrowsError(try file.read(from: 1, to: 6))
            
            XCTAssertEqual(try file.read(from: 0, to: 5), [0x05, 0x04, 0x01, 0x02, 0x03, 0x00])
            
            XCTAssertEqual(gridFS.chunks.name, "fs.chunks")
            XCTAssertEqual(gridFS.files.name, "fs.files")
        }
    }
    
    func testPing() throws {
        for db in TestManager.dbs {
            let documents = try db.execute(dbCommand: [
                "ping": 1
                ])
            
            XCTAssertEqual(documents.count, 1)
            XCTAssertEqual(documents.first?["ok"] as Int32?, 1)
        }
    }

    func testDisconnect() throws {

        let server =  try Server(mongoURL: TestManager.mongoURL)
        XCTAssertTrue(server.isConnected)

        try server.disconnect()
        XCTAssertFalse(server.isConnected)

    }
}
