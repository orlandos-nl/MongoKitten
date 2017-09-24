////
////  ExtendedJSONTests.swift
////  MongoKittenTests
////
////  Created by Joannis Orlandos on 16/06/2017.
////
//
//import Foundation
//import XCTest
//import MongoKitten
//import ExtendedJSON
//
//public class ExtendedJSONTest: XCTestCase {
//    let kittenDocument: Document = [
//        "doubleTest": 0.04,
//        "stringTest": "footer",
//        "documentTest": [
//            "documentSubDoubleTest": 13.37,
//            "subArray": ["henk", "fred", "kaas", "goudvis"] as Document
//            ] as Document,
//        "nonRandomObjectId": try! ObjectId("0123456789ABCDEF01234567"),
//        "currentTime": Date(timeIntervalSince1970: Double(1453589266)),
//        "cool32bitNumber": Int32(9001),
//        "cool64bitNumber": 21312153,
//        "code": JavascriptCode(code: "console.log(\"Hello there\");"),
//        "codeWithScope": JavascriptCode(code: "console.log(\"Hello there\");", withScope: ["hey": "hello"]),
//        "nothing": NSNull(),
//        "data": Binary(data: [34,34,34,34,34], withSubtype: .generic),
//        "boolFalse": false,
//        "boolTrue": true,
//        "timestamp": Timestamp(increment: 2000, timestamp: 8),
//        "regex": RegularExpression(pattern: "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", options: []),
//        "minKey": MinKey(),
//        "maxKey": MaxKey()
//    ]
//
//    func testFormatting() throws {
//        let epoch = 1498911612.912
//
//        let doc: Document = [
//            "date": Date.init(timeIntervalSince1970: epoch)
//        ]
//
//        let extJSON = doc.makeExtendedJSONData()
//        print(doc.makeExtendedJSONString())
//
//        guard let doc2 = try Document(extendedJSON: extJSON) else {
//            XCTFail()
//            return
//        }
//
//        XCTAssertEqual(Date(doc2["date"])?.timeIntervalSince1970, epoch)
//    }
//
//    func testBasics() throws {
//        let extendedJSON = kittenDocument.makeExtendedJSONString(typeSafe: true)
//
//        guard let copyKittenDocument = try Document(extendedJSON: extendedJSON) else {
//            XCTFail()
//            return
//        }
//
//        XCTAssert(copyKittenDocument == kittenDocument)
//    }
//}

