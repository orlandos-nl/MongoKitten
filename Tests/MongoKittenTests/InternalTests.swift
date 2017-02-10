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

class InternalTests: XCTestCase {
    static var allTests: [(String, (InternalTests) -> () throws -> Void)] {
        return [
            ("testNumberSerialization", testNumberSerialization),
            ("testDriverInformation", testDriverInformation)
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

    func testDriverInformation() {
        let driverInfo = MongoDriverInformation(appName: "XCTest")
        let document = driverInfo.makeBSONPrimitive().documentValue
        XCTAssertEqual(document?["driver"]?["name"]?.string,"MongoKitten")
        XCTAssertEqual(document?["application"]?["name"]?.string,"XCTest")
    }
}
