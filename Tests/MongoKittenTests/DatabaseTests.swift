//
//  DatabaseTests.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 21/04/16.
//
//

import XCTest
@testable import MongoKitten

class DatabaseTests: XCTestCase {
    static var allTests: [(String, (DatabaseTests) -> () throws -> Void)] {
        return [
                   ("testUsers", testUsers),
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
    
    func testAsynchronously() throws {
        let timeout: TimeInterval = 10
        
        let condition0 = NSCondition()
        let condition1 = NSCondition()
        let condition2 = NSCondition()
        let condition3 = NSCondition()
        
        try background {
            do {
                _ = try TestManager.db["henk"].insert(["bob": true])
                condition0.broadcast()
            } catch {
                XCTFail()
            }
        }
        
        try background {
            do {
                _ = try TestManager.db["henk"].insert(["klaas": false])
                condition1.broadcast()
            } catch {
                XCTFail()
            }
        }
        
        try background {
            do {
                _ = try TestManager.db["henk"].insert(["piet": 3])
                condition2.broadcast()
            } catch {
                XCTFail()
            }
        }
        
        try background {
            do {
                try TestManager.db["henk"].insert(["harrie": "hallo"])
                condition3.broadcast()
            } catch {
                XCTFail()
            }
        }
        
        condition0.wait(until: Date(timeIntervalSinceNow: timeout))
        condition1.wait(until: Date(timeIntervalSinceNow: timeout))
        condition2.wait(until: Date(timeIntervalSinceNow: timeout))
        condition3.wait(until: Date(timeIntervalSinceNow: timeout))
    }
    
    func testUsers() {
        let roles: Document = [["role": "dbOwner", "db": ~TestManager.db.name]]
        
        try! TestManager.db.createUser("mongokitten-unittest-testuser", password: "hunter2", roles: roles, customData: ["testdata": false])
        
        guard let userInfo = try? TestManager.server.info(for: "mongokitten-unittest-testuser", inDatabase: TestManager.db), let testData = userInfo[0]["customData"]["testdata"].boolValue else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(testData, false)
        
        try! TestManager.db.update(user: "mongokitten-unittest-testuser", password: "hunter2", roles: roles, customData: ["testdata": true])
        
        try! TestManager.db.drop(user: "mongokitten-unittest-testuser")
    }
}
