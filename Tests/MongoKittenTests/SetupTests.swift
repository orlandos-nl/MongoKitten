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
import Async
import MongoKitten
import Foundation
import Dispatch

public class SetupTests: XCTestCase {
//    public static var allTests: [(String, (SetupTests) -> () throws -> Void)] {
//        return [
////            ("testSetup", testSetup),
//        ]
//    }
//    
//    public override func setUp() {
//        super.setUp()
//        
//        try! TestManager.clean()
//    }
//    
//    public override func tearDown() {
//        try! TestManager.disconnect()
//    }
//    
//    func testAgressivePerformance() throws {
//        for db in TestManager.dbs {
//            try db.server.fsync()
//            
//            db.server.cursorStrategy = .aggressive
//            defer { db.server.cursorStrategy = .lazy }
//            
//            var counter = 0
//            
//            for _ in try db["zips"].find() {
//                counter += 1
//            }
//            
//            XCTAssertEqual(counter, 29353)
//        }
//    }
//    
//    func testEfficientPerformance() throws {
//        for db in TestManager.dbs {
//            try db.server.fsync()
//            
//            db.server.cursorStrategy = .intelligent(bufferChunks: 3)
//            defer { db.server.cursorStrategy = .lazy }
//            
//            var counter = 0
//            
//            for _ in try db["zips"].find() {
//                counter += 1
//            }
//            
//            XCTAssertEqual(counter, 29353)
//        }
//    }
//    
//    func testFullPerformance() throws {
//        for db in TestManager.dbs {
//            for start in 0..<5 {
//                var documents = [Document]()
//                for id in (start * 10_000)..<(start + 1) * 10_000 {
//                    documents.append([
//                        "_id": "\(id)",
//                        "customerId": "128374",
//                        "flightId": "AA231",
//                        "dateOfBooking": Date(),
//                        ])
//                }
//                
//                try db["rfd"].insert(contentsOf: documents)
//            }
//            
//            try db.server.fsync(blocking: true)
//            
//            db.server.cursorStrategy = .aggressive
//            defer { db.server.cursorStrategy = .lazy }
//            
//            var counter = 0
//            
//            for _ in try db["rfd"].find() {
//                counter += 1
//            }
//            
//            XCTAssertEqual(counter, numberOfDocuments)
//        }
//    }
//    
    let numberOfDocuments = 50_000
    
    func testInsertPerformance() throws {
        let db = TestManager.db
        
        var futures = [Future<Void>]()
        
        for id in 0..<numberOfDocuments {
            let doc: Document = [
                "_id": "\(id)",
                "customerId": "128374",
                "flightId": "AA231",
                "dateOfBooking": Date(),
            ]
            
            futures.append(db["rfd"].insert(doc).map { _ in })
        }
        
        try futures.flatMap().blockingAwait(timeout: .seconds(10))
        
        XCTAssertEqual(try db["rfd"].count().blockingAwait(), numberOfDocuments)
    }
}

