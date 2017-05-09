//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Foundation
import XCTest
import MongoKitten

class HelperObjectTests: XCTestCase {
    static var allTests: [(String, (HelperObjectTests) -> () throws -> Void)] {
        return [
            ("testIndex", testIndex),
            ("testProjection", testProjection),
            ("testWriteConcern", testWriteConcern),
            ("testReadConcern", testReadConcern),
            ("testCollation", testCollation),
        ]
    }
    
    func testIndex() throws {
        XCTAssertEqual(Int32(IndexParameter.TextIndexVersion.one.makePrimitive()), Int32(1))
        XCTAssertEqual(Int32(IndexParameter.TextIndexVersion.two.makePrimitive()), Int32(2))
    }
    
    func testProjection() throws {
        let projection: Projection = [
            "field", "name", "age", "gender"
        ]
        
        XCTAssertEqual(projection.makePrimitive() as? Document, [
                "field": true,
                "name": true,
                "age": true,
                "gender": true
            ])
    }
    
    func testReadConcern() {
        XCTAssertEqual(ReadConcern.local.makePrimitive() as? Document, [
                "level": ReadConcern.local.rawValue
            ])
    }
    
    func testWriteConcern() {
        let concern = WriteConcern.custom(w: "majority", j: true, wTimeout: 0).makePrimitive()
        
        XCTAssertEqual(concern as? Document, [
                "w": "majority",
                "j": true,
                "wtimeout": 0
            ])
    }
    
    func testCollation() {
        
    }
}
