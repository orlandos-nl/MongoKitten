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
@testable import MongoKitten

class HelperObjectTests: XCTestCase {
    static var allTests: [(String, (HelperObjectTests) -> () throws -> Void)] {
        return [
            ("testIndex", testIndex),
            ("testProjection", testProjection),
            ("testWriteConcern", testWriteConcern),
            ("testReadConcern", testReadConcern),
            ("testCollation", testCollation),
            ("testCustomValueConvertible", testCustomValueConvertible)
        ]
    }
    
    func testIndex() throws {
        XCTAssertEqual(Int32(IndexParameter.TextIndexVersion.one.makePrimitive()), Int32(1))
        XCTAssertEqual(Int32(IndexParameter.TextIndexVersion.two.makePrimitive()), Int32(2))
    }
    
    func testCustomValueConvertible() {
        let specialData = SpecialData("goudvis", withInt: 10)
        let doc: Document = [
            "embedded": [
                "document": [
                    "value": specialData
                ]
            ]
        ]
        
        guard let newSpecialData = SpecialData(doc["embedded"]["document"]["value"]) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(specialData, newSpecialData)
    }
    
    func testProjection() throws {
        let projection: Projection = [
            "field", "name", "age", "gender"
        ]
        
        XCTAssertEqual(projection.makeDocument(), projection.document)
        
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

struct SpecialData : ValueConvertible, Equatable {
    public static func ==(lhs: SpecialData, rhs: SpecialData) -> Bool {
        return lhs.stringData == rhs.stringData && lhs.intData == rhs.intData
    }
    
    var stringData: String
    var intData: Int
    
    init(_ string: String, withInt int: Int) {
        self.stringData = string
        self.intData = int
    }
    
    init?(_ value: BSON.Primitive?) {
        guard let value = value as? Document else {
            return nil
        }
        
        guard let s = value["string"] as? String, let i = Int(value["int"]) else {
            return nil
        }
        
        self.stringData = s
        self.intData = i
    }
    
    func makePrimitive() -> BSON.Primitive {
        return [
            "string": self.stringData,
            "int": self.intData
        ]
    }
}
