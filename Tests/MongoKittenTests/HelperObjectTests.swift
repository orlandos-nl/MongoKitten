//
//  ClientSettingsTest.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 04/01/2017.
//
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
        
    }
    
    func testProjection() throws {
        
    }
}
