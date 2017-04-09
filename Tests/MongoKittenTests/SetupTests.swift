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
import Foundation
import Dispatch

class SetupTests: XCTestCase {
    static var allTests: [(String, (SetupTests) -> () throws -> Void)] {
        return [
//            ("testSetup", testSetup),
        ]
    }
    
    override func setUp() {
        super.setUp()
        
        try! TestManager.clean()
    }
    
    override func tearDown() {
        try! TestManager.disconnect()
    }
    
    func testAgressivePerformance() throws {
        for db in TestManager.dbs {
            try db.server.fsync()
            
            db.server.cursorStrategy = .aggressive
            defer { db.server.cursorStrategy = .lazy }
            
            var counter = 0
            
            for _ in try db["zips"].find() {
                counter += 1
            }
            
            XCTAssertEqual(counter, 29353)
        }
    }
    
    func testEfficientPerformance() throws {
        for db in TestManager.dbs {
            try db.server.fsync()
            
            db.server.cursorStrategy = .intelligent(bufferChunks: 3)
            defer { db.server.cursorStrategy = .lazy }
            
            var counter = 0
            
            for _ in try db["zips"].find() {
                counter += 1
            }
            
            XCTAssertEqual(counter, 29353)
        }
    }
    
    func testFullPerformance() throws {
        testInsertPerformance()
        
        for db in TestManager.dbs {
            try db.server.fsync()
            
            db.server.cursorStrategy = .aggressive
            defer { db.server.cursorStrategy = .lazy }
            
            var counter = 0
            
            for _ in try db["rfd"].find() {
                counter += 1
            }
            
            XCTAssertEqual(counter, numberOfDocuments)
        }
    }
    
    let numberOfDocuments = 50_000
    
    func testInsertPerformance() {
        var documents = [Document]()
        for id in 0..<numberOfDocuments {
            documents.append([
                "_id": "\(id)",
                "customerId": "128374",
                "flightId": "AA231",
                "dateOfBooking": Date(),
                ])
        }
        
        for db in TestManager.dbs {
            let queue = DispatchQueue(label: "insertion", attributes: .concurrent)
            let dispatchGroup = DispatchGroup()
            
            documents.forEach { doc in
                queue.async(group: dispatchGroup) {
                    do {
                        try db["rfd"].insert( doc )
                    } catch let error as InsertErrors {
                        XCTFail("error: \(error)")
                    } catch let error as MongoError {
                        XCTFail("error: \(error)")
                    } catch let error {
                        XCTFail("error: \(error)")
                        // returns timeout
                    }
                    
                }
            }
            
            dispatchGroup.wait()
            
            XCTAssertEqual(try db["rfd"].count(), numberOfDocuments)
        }
    }
}
