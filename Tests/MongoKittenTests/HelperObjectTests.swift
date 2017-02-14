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
            ("testSort", testSort),
            ("testIndex", testIndex),
            ("testProjection", testProjection),
            ("testWriteConcern", testWriteConcern),
            ("testReadConcern", testReadConcern),
            ("testCollation", testCollation),
            ("testCustomValueConvertible", testCustomValueConvertible)
        ]
    }
    
    func testSort() throws {
        guard let kaas = Sort(([
            "order": Int32(-1),
            "otherOrder": Int32(1)
            ] as Document) as BSONPrimitive) else {
                XCTFail()
                return
        }
        
        XCTAssertEqual(kaas.makeDocument(), (["order": .descending, "otherOrder": .ascending] as Sort).makeDocument())
    }
    
    func testIndex() throws {
        XCTAssertEqual(IndexParameter.TextIndexVersion.one.makeBSONPrimitive() as? Int32, Int32(1))
        XCTAssertEqual(IndexParameter.TextIndexVersion.two.makeBSONPrimitive() as? Int32, Int32(2))
    }
    
    func testCustomValueConvertible() {
        let specialData = SpecialData("goudvis", withInt: 10)
        let doc: Document = [
            "embedded": [
                "document": [
                    "value": specialData
                ] as Document
            ] as Document
        ]
        
        guard let newSpecialData = doc.extract("embedded", "document", "value") as SpecialData? else {
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
        
        XCTAssertEqual(projection.makeBSONPrimitive() as? Document, [
                "field": true,
                "name": true,
                "age": true,
                "gender": true
            ] as Document)
    }
    
    func testReadConcern() {
        XCTAssertEqual(ReadConcern.local.makeBSONPrimitive() as? Document, [
                "level": ReadConcern.local.rawValue
            ] as Document)
    }
    
    func testWriteConcern() {
        let concern = WriteConcern.custom(w: "majority", j: true, wTimeout: 0).makeBSONPrimitive()
        
        XCTAssertEqual(concern as? Document, [
                "w": "majority",
                "j": true,
                "wtimeout": 0
            ] as Document)
    }
    
    func testCollation() {
        
    }
}

struct SpecialData : CustomValueConvertible, Equatable {
    public static func ==(lhs: SpecialData, rhs: SpecialData) -> Bool {
        return lhs.stringData == rhs.stringData && lhs.intData == rhs.intData
    }
    
    var stringData: String
    var intData: Int
    
    init(_ string: String, withInt int: Int) {
        self.stringData = string
        self.intData = int
    }
    
    init?(_ value: BSONPrimitive) {
        guard let value = value as? Document else {
            return nil
        }
        
        guard let s = value["string"] as String?, let i = value["int"] as Int? else {
            return nil
        }
        
        self.stringData = s
        self.intData = i
    }
    
    func makeBSONPrimitive() -> BSONPrimitive {
        return [
            "string": self.stringData,
            "int": self.intData
        ] as Document
    }
}
