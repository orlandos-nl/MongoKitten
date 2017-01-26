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

class InternalTests: XCTestCase {
    static var allTests: [(String, (InternalTests) -> () throws -> Void)] {
        return [
            ("testNumberSerialization", testNumberSerialization),
        ]
    }
    
    func testNumberSerialization() throws {
        XCTAssertEqual(Int(14).makeBytes(), [14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        XCTAssertEqual(Int64(14).makeBytes(), [14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        XCTAssertEqual(Int16(500).makeBytes(), [0x01, 244])
        
        XCTAssertEqual(Int8(123).makeBytes(), [123])
        
        XCTAssertEqual(UInt(2048).makeBytes(), [0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        XCTAssertEqual(UInt64(2048).makeBytes(), [0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        XCTAssertEqual(UInt32(2560).makeBytes(), [0x00, 0x0a, 0x00, 0x00])
        
        XCTAssertEqual(UInt16.max.makeBytes(), [0xff, 0xff])
        
        XCTAssertEqual(UInt8.max.makeBytes(), [0xff])

        XCTAssertEqual(Double(10).makeBytes(), [0x00, 0x00,0x00,0x00,0x00,0x00, 0x24, 0x40])
    }
}
